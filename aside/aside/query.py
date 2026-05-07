"""Query pipeline: send text to an LLM, stream response, run tools, speak.

Uses LiteLLM for model-agnostic API calls (OpenAI, Anthropic, etc.).
All functions are self-contained helpers with no daemon/socket dependencies.
Called by the aside daemon and CLI.
"""

from __future__ import annotations

import json
import logging
import os
import re
import socket
import subprocess
import threading
import urllib.request
from datetime import datetime
from pathlib import Path

import litellm

from aside.config import resolve_socket_path
from aside.plugins import run_tool
from aside.sentence_buffer import SentenceBuffer

log = logging.getLogger("aside")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MAX_TOKENS = 4096
MAX_TOOL_ROUNDS = 8
MAX_TOOL_RESULT_CHARS = 20000
FORCED_WEB_SEARCH_TOOL_ID = "forced_web_search"
WEB_SEARCH_RE = re.compile(
    r"(?:\b(?:search|find|google|web|internet|online|latest|current|today|news)\b|"
    r"найди|найти|поищи|поиск|загугли|интернет|в интернете|сети|новост|"
    r"свеж|актуальн|последн)",
    re.IGNORECASE,
)

# Sentinel for explicit "start a new conversation"
NEW_CONVERSATION = object()


class ContextWindowFull(Exception):
    """Raised when the conversation exceeds the model's context window."""
    pass


# ---------------------------------------------------------------------------
# System prompt
# ---------------------------------------------------------------------------

def _build_system_prompt(config_dir: Path | None = None) -> str:
    """Build system prompt from date line + optional agent.md file.

    Reads ``agent.md`` from *config_dir* (defaults to
    ``~/.config/aside/``) on every call so edits take effect immediately.
    """
    now = datetime.now()
    date_line = "Today is {long} ({iso}, {weekday}).".format(
        long=now.strftime("%d %B %Y"),
        iso=now.strftime("%Y-%m-%d"),
        weekday=now.strftime("%A"),
    )

    if config_dir is None:
        config_dir = Path(
            os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")
        ) / "aside"

    agent_file = config_dir / "agent.md"
    if agent_file.is_file():
        return date_line + "\n\n" + agent_file.read_text().strip()

    return date_line


# ---------------------------------------------------------------------------
# Message building (OpenAI / LiteLLM format)
# ---------------------------------------------------------------------------


def _build_messages(
    text: str,
    history: list[dict],
    system_prompt: str,
    image: str | None = None,
    file: str | None = None,
) -> list[dict]:
    """Build an OpenAI-format messages list for LiteLLM.

    Parameters
    ----------
    text:
        The user's current message text.
    history:
        Prior messages in OpenAI format (``[{"role": ..., "content": ...}, ...]``).
    system_prompt:
        Placed as the first ``{"role": "system", ...}`` message.
    image:
        Optional base64-encoded PNG image to attach to the user message.
    file:
        Optional file path string.  Prepended as context to *text*.
    """
    messages: list[dict] = []

    # System message first.
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})

    # Prior conversation history.
    messages.extend(history)

    # Current user message.
    if file:
        text = (
            f"[Attached file: {file}]\n"
            "When you produce an output file, copy it to the clipboard "
            "using the clipboard tool's file parameter.\n\n" + text
        )

    if image:
        user_content = [
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/png;base64,{image}",
                },
            },
            {"type": "text", "text": text},
        ]
    else:
        user_content = text  # type: ignore[assignment]

    messages.append({"role": "user", "content": user_content})
    return messages


# ---------------------------------------------------------------------------
# Tool-call accumulation from streaming chunks
# ---------------------------------------------------------------------------


def _getval(obj, key: str, default=""):
    """Get a value from either a dict or an attribute-based object."""
    if isinstance(obj, dict):
        return obj.get(key, default)
    return getattr(obj, key, default)


def _accumulate_tool_calls(
    existing: dict[int, dict],
    delta_tool_calls: list,
) -> None:
    """Merge incremental ``delta.tool_calls`` into *existing*.

    LiteLLM / OpenAI stream tool calls incrementally:
    - The first chunk for an index carries ``function.name``.
    - Subsequent chunks append to ``function.arguments``.

    *existing* is keyed by tool-call index and mutated in place.
    """
    for tc in delta_tool_calls:
        idx = _getval(tc, "index", 0)
        if idx not in existing:
            existing[idx] = {
                "id": _getval(tc, "id", "") or "",
                "name": "",
                "arguments": "",
            }
        entry = existing[idx]

        # Update id if non-empty (may arrive on first chunk).
        tc_id = _getval(tc, "id", "") or ""
        if tc_id:
            entry["id"] = tc_id

        fn = _getval(tc, "function", None)
        if fn is None:
            fn = {}

        fn_name = _getval(fn, "name", "") or ""
        fn_args = _getval(fn, "arguments", "") or ""

        if fn_name:
            entry["name"] = fn_name
        entry["arguments"] += fn_args


def _parse_tool_calls(accumulated: dict[int, dict]) -> list[dict]:
    """Convert accumulated tool-call fragments into finished dicts.

    Each returned dict has ``id``, ``name``, and ``arguments`` (parsed JSON).
    """
    results: list[dict] = []
    for idx in sorted(accumulated):
        entry = accumulated[idx]
        name = str(entry.get("name") or "").strip()
        if not name:
            log.warning("Skipping tool call without a function name at index %s", idx)
            continue
        try:
            args = json.loads(entry["arguments"]) if entry["arguments"] else {}
        except json.JSONDecodeError:
            log.warning("Failed to parse tool arguments for %s: %s",
                        name, entry["arguments"][:200])
            args = {}
        if not isinstance(args, dict):
            log.warning("Tool arguments for %s are not an object", name)
            args = {}
        results.append({
            "id": str(entry.get("id") or f"call_{idx}"),
            "name": name,
            "arguments": args,
        })
    return results


def _format_tool_result(result: object, max_chars: int = MAX_TOOL_RESULT_CHARS) -> str:
    if isinstance(result, dict) and result.get("type") == "image":
        text = json.dumps({
            "type": "image",
            "media_type": result.get("media_type", "image/png"),
            "base64": result.get("base64") or result.get("data") or "",
        }, ensure_ascii=False, default=str)
    elif isinstance(result, (dict, list)):
        text = json.dumps(result, ensure_ascii=False, default=str)
    else:
        text = str(result)
    if len(text) > max_chars:
        return text[:max_chars] + f"\n\n[truncated to {max_chars} characters]"
    return text


def _tool_available(tools: list[dict] | None, name: str) -> bool:
    for tool in tools or []:
        function = tool.get("function", {})
        if function.get("name") == name:
            return True
    return False


def _should_force_web_search(text: str, tools: list[dict] | None, config: dict) -> bool:
    if not config.get("tools", {}).get("force_web_search", True):
        return False
    if not _tool_available(tools, "web_search"):
        return False
    return bool(WEB_SEARCH_RE.search(text or ""))


def _with_no_think(messages: list[dict], model: str, disable: bool) -> list[dict]:
    if not disable or not model.startswith("ollama/"):
        return messages
    copied = [dict(message) for message in messages]
    for message in reversed(copied):
        if message.get("role") != "user":
            continue
        content = message.get("content")
        if isinstance(content, str):
            if "/no_think" not in content:
                message["content"] = content.rstrip() + "\n\n/no_think"
            return copied
        if isinstance(content, list):
            items = [dict(item) if isinstance(item, dict) else item for item in content]
            for item in reversed(items):
                if isinstance(item, dict) and item.get("type") == "text":
                    text = str(item.get("text") or "")
                    if "/no_think" not in text:
                        item["text"] = text.rstrip() + "\n\n/no_think"
                    message["content"] = items
                    return copied
    return copied


def _content_to_text(content: object) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(str(item.get("text") or ""))
            elif isinstance(item, dict) and item.get("type") == "image_url":
                parts.append("[image attached]")
            else:
                parts.append(str(item))
        return "\n".join(part for part in parts if part)
    return str(content)


def _ollama_messages_to_text(messages: list[dict]) -> list[dict]:
    converted: list[dict] = []
    for message in messages:
        role = str(message.get("role") or "user")
        content = _content_to_text(message.get("content"))
        tool_calls = message.get("tool_calls") or []
        if tool_calls:
            rendered_calls = []
            for tool_call in tool_calls:
                function = tool_call.get("function", {})
                rendered_calls.append(
                    f"{function.get('name', 'tool')}({function.get('arguments', '{}')})"
                )
            content = "\n".join(
                part for part in [content, "Tool call: " + "; ".join(rendered_calls)] if part
            )
        if role == "tool":
            content = "Tool result:\n" + content
        converted.append({"role": role, "content": f"{role}: {content}" if content else f"{role}:"})
    return converted


def _prepare_messages_for_model(messages: list[dict], model: str, disable_thinking: bool) -> list[dict]:
    prepared = _with_no_think(messages, model, disable_thinking)
    if model.startswith("ollama/"):
        converted = _ollama_messages_to_text(prepared)
        if disable_thinking and converted and "/no_think" not in converted[-1]["content"]:
            converted[-1]["content"] = converted[-1]["content"].rstrip() + "\n\n/no_think"
        return converted
    return prepared


def _ollama_prompt(messages: list[dict]) -> str:
    return "\n\n".join(_content_to_text(message.get("content")) for message in messages)


def _ollama_generate_stream(
    model: str,
    messages: list[dict],
    api_base: str | None,
    timeout: int | float,
    keep_alive: str,
    think: bool | None = None,
):
    endpoint = (api_base or "http://localhost:11434").rstrip("/")
    if endpoint.endswith("/api/generate"):
        url = endpoint
    else:
        url = endpoint + "/api/generate"
    model_name = model.split("/", 1)[1] if model.startswith("ollama/") else model
    payload = {
        "model": model_name,
        "prompt": _ollama_prompt(messages),
        "stream": True,
        "keep_alive": keep_alive,
        "options": {
            "num_predict": MAX_TOKENS,
        },
    }
    if think is not None:
        payload["think"] = think
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    return urllib.request.urlopen(req, timeout=timeout)


# ---------------------------------------------------------------------------
# Overlay IPC
# ---------------------------------------------------------------------------


def _connect_overlay() -> socket.socket | None:
    """Connect to the aside-overlay Unix socket.  Returns socket or None."""
    sock_path = resolve_socket_path("aside-overlay.sock")
    try:
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.connect(str(sock_path))
        log.debug("overlay: connected to %s", sock_path)
        return sock
    except (ConnectionRefusedError, FileNotFoundError, OSError) as e:
        log.warning("overlay: connect failed: %s", e)
        return None


def _overlay_send(sock: socket.socket | None, msg: dict) -> None:
    """Send a JSON-line command to the overlay.  Swallows errors."""
    payload = (json.dumps(msg) + "\n").encode("utf-8")
    if sock is None:
        retry_sock = _connect_overlay()
        if retry_sock is None:
            log.debug("overlay_send: no socket, dropping cmd=%s", msg.get("cmd"))
            return
        try:
            retry_sock.sendall(payload)
            log.debug("overlay_send: cmd=%s", msg.get("cmd"))
        except (BrokenPipeError, OSError) as e:
            log.warning("overlay_send: retry failed cmd=%s: %s", msg.get("cmd"), e)
        finally:
            _overlay_close(retry_sock)
        return
    try:
        sock.sendall(payload)
        log.debug("overlay_send: cmd=%s", msg.get("cmd"))
    except (BrokenPipeError, OSError) as e:
        log.warning("overlay_send: error sending cmd=%s: %s", msg.get("cmd"), e)
        retry_sock = _connect_overlay()
        if retry_sock is None:
            return
        try:
            retry_sock.sendall(payload)
            log.debug("overlay_send: retry cmd=%s", msg.get("cmd"))
        except (BrokenPipeError, OSError) as retry_error:
            log.warning("overlay_send: retry failed cmd=%s: %s", msg.get("cmd"), retry_error)
        finally:
            _overlay_close(retry_sock)


def _overlay_close(sock: socket.socket | None) -> None:
    """Close overlay socket, ignoring errors."""
    if sock is None:
        return
    try:
        sock.close()
    except OSError:
        pass


# ---------------------------------------------------------------------------
# Error notification
# ---------------------------------------------------------------------------


def notify_error(message: str) -> None:
    """Fire-and-forget critical error notification via notify-send."""
    try:
        subprocess.Popen(
            ["notify-send", "-u", "critical", "-a", "Aside", "Aside", message],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


def _notify_model_not_found(model: str) -> None:
    """Show a notification for a model-not-found error with an action to copy the exclude command."""
    exclude_cmd = f"aside model exclude {model}"
    try:
        result = subprocess.run(
            [
                "notify-send", "-u", "critical", "-a", "Aside",
                "--action=copy=Copy exclude command",
                "Aside — model not found",
                f"{model} is deprecated or unavailable.",
            ],
            capture_output=True, text=True, timeout=30,
        )
        if result.stdout.strip() == "copy":
            subprocess.run(
                ["wl-copy", exclude_cmd],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                timeout=5,
            )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        # Fallback: simple fire-and-forget notification
        notify_error(f"Model not found: {model}\nRun: {exclude_cmd}")


# ---------------------------------------------------------------------------
# Streaming API call
# ---------------------------------------------------------------------------


def stream_response(
    model: str,
    messages: list[dict],
    tools: list[dict],
    cancel_event: threading.Event | None,
    overlay_sock: socket.socket | None,
    tts,  # TTSPipeline | None
    sentence_buf: SentenceBuffer,
    speak_on: bool,
    deferred_open: dict | None = None,
    timeout: int | float = 30,
    api_base: str | None = None,
    ollama_fast_path: bool = True,
    ollama_keep_alive: str = "30m",
    ollama_think: bool | None = None,
) -> tuple[str, list[dict], dict]:
    """Stream an LLM response via LiteLLM.

    Returns ``(accumulated_text, tool_calls, usage_dict)`` where:
    - *accumulated_text* is the full assistant text content.
    - *tool_calls* is a list of ``{"id": ..., "name": ..., "arguments": {...}}``.
    - *usage_dict* has ``model``, ``input_tokens``, ``output_tokens`` (may be
      zeroed if the provider doesn't report usage).

    When *deferred_open* is provided (mic→agent transition), the overlay
    "open" command is sent only when the first content chunk arrives,
    keeping the user's transcribed text visible until then.
    """
    api_kwargs: dict = {
        "model": model,
        "messages": messages,
        "max_tokens": MAX_TOKENS,
        "stream": True,
        "stream_options": {"include_usage": True},
        "timeout": timeout,
    }
    if tools:
        api_kwargs["tools"] = tools
    if api_base:
        api_kwargs["api_base"] = api_base

    accumulated_text = ""
    accumulated_tool_calls: dict[int, dict] = {}
    usage = {"model": model, "input_tokens": 0, "output_tokens": 0}
    open_sent = deferred_open is None  # True if no deferred open needed

    if ollama_fast_path and model.startswith("ollama/"):
        response_stream = _ollama_generate_stream(
            model=model,
            messages=messages,
            api_base=api_base,
            timeout=timeout,
            keep_alive=ollama_keep_alive,
            think=ollama_think,
        )
        try:
            for raw_line in response_stream:
                if cancel_event and cancel_event.is_set():
                    if hasattr(response_stream, "close"):
                        response_stream.close()
                    return accumulated_text, [], usage

                line = raw_line.decode("utf-8").strip() if isinstance(raw_line, bytes) else str(raw_line).strip()
                if not line:
                    continue

                data = json.loads(line)
                if data.get("error"):
                    raise RuntimeError(data["error"])

                delta_content = data.get("response") or ""
                if delta_content:
                    if not open_sent and deferred_open:
                        _overlay_send(overlay_sock, deferred_open)
                        open_sent = True

                    accumulated_text += delta_content
                    if speak_on and tts is not None:
                        for sentence in sentence_buf.add(delta_content):
                            tts.speak(sentence)
                    _overlay_send(overlay_sock, {
                        "cmd": "text",
                        "data": delta_content,
                    })

                if data.get("done"):
                    usage["model"] = "ollama/" + (data.get("model") or model.split("/", 1)[1])
                    usage["input_tokens"] = data.get("prompt_eval_count", 0) or 0
                    usage["output_tokens"] = data.get("eval_count", 0) or 0
                    break
        finally:
            if hasattr(response_stream, "close"):
                response_stream.close()

        if not open_sent and deferred_open:
            _overlay_send(overlay_sock, deferred_open)

        if speak_on and tts is not None:
            for sentence in sentence_buf.flush():
                tts.speak(sentence)

        return accumulated_text, [], usage

    response_stream = litellm.completion(**api_kwargs)

    for chunk in response_stream:
        if cancel_event and cancel_event.is_set():
            # Don't send overlay commands here — the new operation
            # (mic capture, new query) already owns the overlay.
            # Explicit cancels are handled by the cancel socket handler.
            if hasattr(response_stream, "close"):
                response_stream.close()
            return accumulated_text, [], usage

        choices = _getval(chunk, "choices", [])
        choice = choices[0] if choices else None
        if choice is None:
            # Usage-only final chunk (no choices).
            usage_obj = _getval(chunk, "usage", None)
            if usage_obj is not None:
                usage["input_tokens"] = _getval(usage_obj, "prompt_tokens", 0) or 0
                usage["output_tokens"] = _getval(usage_obj, "completion_tokens", 0) or 0
                usage["model"] = _getval(chunk, "model", model) or model
            continue

        delta = _getval(choice, "delta", None)
        delta_content = _getval(delta, "content", "") if delta else ""
        delta_tool_calls = _getval(delta, "tool_calls", []) if delta else []

        # Send deferred open on first real content (text or tool call).
        if not open_sent and delta and (delta_content or delta_tool_calls):
            _overlay_send(overlay_sock, deferred_open)
            open_sent = True

        # Text content.
        if delta and delta_content:
            accumulated_text += delta_content

            if speak_on and tts is not None:
                for sentence in sentence_buf.add(delta_content):
                    tts.speak(sentence)

            _overlay_send(overlay_sock, {
                "cmd": "text",
                "data": delta_content,
            })

        # Tool calls (streamed incrementally).
        if delta and delta_tool_calls:
            _accumulate_tool_calls(accumulated_tool_calls, delta_tool_calls)

        # Usage from the last chunk (some providers put it on the final choice).
        usage_obj = _getval(chunk, "usage", None)
        if usage_obj is not None:
            usage["input_tokens"] = _getval(usage_obj, "prompt_tokens", 0) or 0
            usage["output_tokens"] = _getval(usage_obj, "completion_tokens", 0) or 0
            usage["model"] = _getval(chunk, "model", model) or model

    # If stream ended without sending the deferred open, send it now.
    if not open_sent and deferred_open:
        _overlay_send(overlay_sock, deferred_open)

    # Flush remaining TTS.
    if speak_on and tts is not None:
        for sentence in sentence_buf.flush():
            tts.speak(sentence)

    tool_calls = _parse_tool_calls(accumulated_tool_calls)
    return accumulated_text, tool_calls, usage


# ---------------------------------------------------------------------------
# Main query pipeline
# ---------------------------------------------------------------------------


def send_query(
    text: str,
    conversation_id,
    config: dict,
    store,          # ConversationStore
    status,         # StatusState
    usage_log,      # UsageLog
    cancel_event: threading.Event | None = None,
    image: str | None = None,
    file: str | None = None,
    tts=None,       # TTSPipeline | None
    plugin_dirs: list[Path] | None = None,
    tools: list[dict] | None = None,
    from_mic: bool = False,
) -> str | None:
    """Send text to an LLM.  The single entry point for all query paths.

    Parameters
    ----------
    text:
        The user's message.
    conversation_id:
        - ``None`` -> continue last conversation (or start new)
        - ``NEW_CONVERSATION`` -> explicit fresh conversation
        - ``"uuid-string"`` -> continue that specific conversation
    config:
        Full config dict (from ``load_config``).
    store:
        A ``ConversationStore`` instance.
    status:
        A ``StatusState`` instance (for status bar updates).
    usage_log:
        A ``UsageLog`` instance.
    cancel_event:
        Optional event to signal cancellation.
    image:
        Optional base64-encoded PNG.
    file:
        Optional file path string for file context.
    tts:
        Optional ``TTSPipeline`` instance.
    plugin_dirs:
        Directories to scan for tool plugins.
    tools:
        Pre-loaded tool definitions (OpenAI format).  If ``None``, no tools.
    from_mic:
        When True, the overlay already shows the user's transcribed text
        in thinking/pulsing mode.  The "open" command is deferred until
        the first LLM response chunk arrives.

    Returns the conversation id, or ``None`` if cancelled before any streaming.
    """
    # ------------------------------------------------------------------
    # Resolve conversation
    # ------------------------------------------------------------------
    if conversation_id is NEW_CONVERSATION:
        conv = store.get_or_create()
    elif conversation_id is not None:
        conv = store.get_or_create(conversation_id)
    else:
        resolved = store.resolve_last()
        conv = store.get_or_create(resolved) if resolved else store.get_or_create()

    model = config.get("model", {}).get("name", "anthropic/claude-sonnet-4-6")
    timeout = config.get("model", {}).get("timeout", 30)
    api_base = config.get("model", {}).get("api_base")
    if not api_base and model.startswith("ollama/"):
        api_base = "http://localhost:11434"
    system_prompt = _build_system_prompt()

    # ------------------------------------------------------------------
    # TTS setup
    # ------------------------------------------------------------------
    speak_on = False
    tts_config = config.get("tts", {})
    if tts is not None:
        speak_on = status.speak_enabled or (
            from_mic and bool(tts_config.get("mic_enabled", True))
        )
    if speak_on and tts is not None:
        tts.start()
        status.set_status("speaking")
    else:
        status.set_status("thinking")

    # ------------------------------------------------------------------
    # Build initial user message and add to conversation
    # ------------------------------------------------------------------
    if file:
        user_text = (
            f"[Attached file: {file}]\n"
            "When you produce an output file, copy it to the clipboard "
            "using the clipboard tool's file parameter.\n\n" + text
        )
    else:
        user_text = text

    if image:
        user_content = [
            {
                "type": "image_url",
                "image_url": {"url": f"data:image/png;base64,{image}"},
            },
            {"type": "text", "text": user_text},
        ]
    else:
        user_content = user_text  # type: ignore[assignment]

    conv["messages"].append({"role": "user", "content": user_content})
    store.write_transcript(conv)

    # ------------------------------------------------------------------
    # Streaming loop with tool execution
    # ------------------------------------------------------------------
    full_text = ""
    overlay_sock = _connect_overlay()
    if speak_on and tts is not None and hasattr(tts, "set_audio_level_callback"):
        def on_tts_audio_level(level):
            _overlay_send(overlay_sock, {"cmd": "audio_level", "data": level})
        tts.set_audio_level_callback(on_tts_audio_level)
    open_cmd = {"cmd": "open", "mode": "agent", "conv_id": conv["id"]}
    deferred_open: dict | None = None

    if from_mic:
        # Overlay is already visible with user text + thinking dots.
        # Send stream_start (keeps user text, adds assistant message)
        # instead of open (which clears everything).
        deferred_open = {"cmd": "stream_start", "conv_id": conv["id"]}
    else:
        _overlay_send(overlay_sock, open_cmd)

    sentence_buf = SentenceBuffer()
    session_tokens = 0
    dirs = plugin_dirs or []
    tool_rounds = 0
    max_tool_rounds = int(config.get("tools", {}).get("max_rounds", MAX_TOOL_ROUNDS))
    model_config = config.get("model", {})
    disable_thinking = bool(model_config.get("disable_thinking", True))
    ollama_fast_path = bool(model_config.get("ollama_fast_path", True))
    ollama_keep_alive = str(model_config.get("ollama_keep_alive", "30m"))
    ollama_think = False if disable_thinking else model_config.get("ollama_think")

    try:
        if (
            _should_force_web_search(text, tools, config)
            and not (cancel_event and cancel_event.is_set())
        ):
            if deferred_open:
                _overlay_send(overlay_sock, deferred_open)
                deferred_open = None

            search_args = {
                "query": text,
                "max_results": config.get("tools", {}).get("web_search_max_results", 5),
            }
            conv["messages"].append({
                "role": "assistant",
                "content": None,
                "tool_calls": [{
                    "id": FORCED_WEB_SEARCH_TOOL_ID,
                    "type": "function",
                    "function": {
                        "name": "web_search",
                        "arguments": json.dumps(search_args),
                    },
                }],
            })
            store.write_transcript(conv)

            log.info("Executing forced tool: web_search")
            status.set_status("tool_use", tool_name="web_search")
            result = run_tool("web_search", search_args, dirs)
            conv["messages"].append({
                "role": "tool",
                "tool_call_id": FORCED_WEB_SEARCH_TOOL_ID,
                "content": _format_tool_result(result),
            })
            store.write_transcript(conv)

            full_text += "web_search\n\n"
            _overlay_send(overlay_sock, {"cmd": "replace", "data": full_text})
            _overlay_send(overlay_sock, {"cmd": "thinking"})
            if speak_on and tts is not None and tts._running:
                status.set_status("speaking")
            else:
                status.set_status("thinking")

        while True:
            # Build the messages list fresh each iteration (system + history).
            messages = _build_messages(
                text="",  # text is already in conv["messages"]
                history=conv["messages"],
                system_prompt=system_prompt,
                image=None,  # image is already in conv["messages"]
            )
            # Remove the empty trailing user message that _build_messages appends.
            messages.pop()
            messages = _prepare_messages_for_model(messages, model, disable_thinking)

            resp_text, tool_calls, usage = stream_response(
                model=model,
                messages=messages,
                tools=tools or [],
                cancel_event=cancel_event,
                overlay_sock=overlay_sock,
                tts=tts,
                sentence_buf=sentence_buf,
                speak_on=speak_on,
                deferred_open=deferred_open,
                timeout=timeout,
                api_base=api_base,
                ollama_fast_path=ollama_fast_path,
                ollama_keep_alive=ollama_keep_alive,
                ollama_think=ollama_think,
            )
            deferred_open = None  # Only defer on the first iteration

            # Cancelled.
            if cancel_event and cancel_event.is_set() and not resp_text and not tool_calls:
                break

            full_text += resp_text

            # Log usage.
            usage_log.log(usage["model"], usage["input_tokens"], usage["output_tokens"])
            session_tokens += usage["input_tokens"] + usage["output_tokens"]
            status.update_usage(session_tokens)

            # Build assistant message for conversation history.
            assistant_msg: dict = {"role": "assistant", "content": resp_text or ""}
            if tool_calls:
                assistant_msg["tool_calls"] = [
                    {
                        "id": tc["id"],
                        "type": "function",
                        "function": {
                            "name": tc["name"],
                            "arguments": json.dumps(tc["arguments"]),
                        },
                    }
                    for tc in tool_calls
                ]
                # OpenAI format: when there are tool_calls, content can be null.
                if not resp_text:
                    assistant_msg["content"] = None
            conv["messages"].append(assistant_msg)
            store.write_transcript(conv)

            if not tool_calls or (cancel_event and cancel_event.is_set()):
                break

            tool_rounds += 1
            if tool_rounds > max_tool_rounds:
                limit_msg = f"Stopped after {max_tool_rounds} tool-call rounds."
                for tc in tool_calls:
                    conv["messages"].append({
                        "role": "tool",
                        "tool_call_id": tc["id"],
                        "content": limit_msg,
                    })
                if full_text:
                    full_text += "\n\n"
                full_text += limit_msg
                _overlay_send(overlay_sock, {"cmd": "replace", "data": full_text})
                store.write_transcript(conv)
                break

            for tc in tool_calls:
                if cancel_event and cancel_event.is_set():
                    break
                log.info("Executing tool: %s", tc["name"])
                status.set_status("tool_use", tool_name=tc["name"])
                result = run_tool(tc["name"], tc["arguments"], dirs)

                conv["messages"].append({
                    "role": "tool",
                    "tool_call_id": tc["id"],
                    "content": _format_tool_result(result),
                })

            store.write_transcript(conv)

            # Update overlay with tool execution info.
            tool_names = " \u2192 ".join(tc["name"] for tc in tool_calls)
            if full_text:
                full_text += "\n\n"
            full_text += f"{tool_names}\n\n"
            _overlay_send(overlay_sock, {"cmd": "replace", "data": full_text})
            # Show accent sweep while waiting for the next LLM response.
            # CMD_TEXT in the overlay will clear thinking_active automatically.
            _overlay_send(overlay_sock, {"cmd": "thinking"})
            if speak_on and tts is not None and tts._running:
                status.set_status("speaking")
            else:
                status.set_status("thinking")

        # Save conversation.
        store.save(conv)
        store.save_last(conv["id"])

        # Wait for TTS.
        if tts is not None and tts._running:
            if cancel_event and cancel_event.is_set():
                tts.stop()
            else:
                tts.finish()
                tts.wait_done(120)
                tts.stop()

        log.info("Conversation %s complete (%d messages)",
                 conv["id"][:8], len(conv["messages"]))

        # Fade out overlay — but not if cancelled, since a new operation
        # (mic capture, new query) already owns the overlay.
        if not (cancel_event and cancel_event.is_set()):
            _overlay_send(overlay_sock, {"cmd": "done"})
        _overlay_close(overlay_sock)

        return conv["id"]

    except litellm.ContextWindowExceededError:
        log.warning("Context window exceeded for conversation %s", conv["id"][:8])
        _overlay_send(overlay_sock, {"cmd": "clear"})
        _overlay_close(overlay_sock)
        notify_error("Conversation too long — starting a new one")
        if tts is not None:
            tts.stop()
        store.save(conv)
        # Raise so the daemon can retry with a fresh conversation.
        raise ContextWindowFull()

    except getattr(litellm, "BadRequestError", getattr(litellm, "InvalidRequestError", type("DummyError", (Exception,), {}))) as e:
        if "request_too_large" in str(e):
            log.warning("Request too large for conversation %s", conv["id"][:8])
            _overlay_send(overlay_sock, {"cmd": "clear"})
            _overlay_close(overlay_sock)
            notify_error("Conversation too long — starting a new one")
            if tts is not None:
                tts.stop()
            store.save(conv)
            raise ContextWindowFull()
        raise  # Re-raise other BadRequestErrors to be caught by APIError below

    except getattr(litellm.exceptions, "NotFoundError", getattr(litellm, "NotFoundError", type("DummyError", (Exception,), {}))) as e:
        log.error("Model not found: %s — %s", model, e)
        _overlay_send(overlay_sock, {"cmd": "clear"})
        _overlay_close(overlay_sock)
        _notify_model_not_found(model)
        if tts is not None:
            tts.stop()
        store.save(conv)
        return conv["id"]
    except getattr(litellm.exceptions, "AuthenticationError", getattr(litellm, "AuthenticationError", type("DummyError", (Exception,), {}))) as e:
        log.error("Authentication error: %s", e)
        _overlay_send(overlay_sock, {"cmd": "clear"})
        _overlay_close(overlay_sock)
        notify_error("API key missing or invalid — check env vars")
        if tts is not None:
            tts.stop()
        store.save(conv)
        return conv["id"]
    except getattr(litellm.exceptions, "APIError", getattr(litellm, "APIError", type("DummyError", (Exception,), {}))) as e:
        log.error("API error: %s", e)
        _overlay_send(overlay_sock, {"cmd": "clear"})
        _overlay_close(overlay_sock)
        notify_error(f"API error: {e}")
        if tts is not None:
            tts.stop()
        store.save(conv)
        return conv["id"]
    except Exception as e:
        log.exception("Unexpected error during query")
        _overlay_send(overlay_sock, {"cmd": "clear"})
        _overlay_close(overlay_sock)
        short = str(e)[:200] if str(e) else type(e).__name__
        notify_error(f"Error: {short}")
        if tts is not None:
            tts.stop()
        store.save(conv)
        return conv["id"]
    finally:
        if tts is not None and hasattr(tts, "set_audio_level_callback"):
            tts.set_audio_level_callback(None)
        status.set_status("idle")
