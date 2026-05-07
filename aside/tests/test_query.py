"""Tests for aside.query — message building, tool accumulation, error notifications."""

from __future__ import annotations

import json
import threading
from types import SimpleNamespace
from unittest import mock

import pytest

from aside.query import (
    NEW_CONVERSATION,
    _accumulate_tool_calls,
    _build_messages,
    _build_system_prompt,
    _format_tool_result,
    _prepare_messages_for_model,
    _parse_tool_calls,
    _should_force_web_search,
    notify_error,
    send_query,
    stream_response,
)


# ---------------------------------------------------------------------------
# _build_system_prompt
# ---------------------------------------------------------------------------


class TestBuildSystemPrompt:
    def test_date_always_present(self):
        prompt = _build_system_prompt()
        from datetime import datetime
        today = datetime.now().strftime("%Y-%m-%d")
        assert today in prompt

    def test_weekday_present(self):
        prompt = _build_system_prompt()
        from datetime import datetime
        weekday = datetime.now().strftime("%A")
        assert weekday in prompt

    def test_with_agent_md(self, tmp_path):
        agent_file = tmp_path / "agent.md"
        agent_file.write_text("You are a pirate. Say arrr.")
        prompt = _build_system_prompt(config_dir=tmp_path)
        assert "You are a pirate. Say arrr." in prompt
        # Date is still there
        from datetime import datetime
        assert datetime.now().strftime("%Y-%m-%d") in prompt

    def test_no_agent_md(self, tmp_path):
        prompt = _build_system_prompt(config_dir=tmp_path)
        # Just the date line, nothing else
        from datetime import datetime
        assert datetime.now().strftime("%Y-%m-%d") in prompt
        assert len(prompt.strip().splitlines()) == 1

    def test_no_hardcoded_persona(self, tmp_path):
        prompt = _build_system_prompt(config_dir=tmp_path)
        assert "Arch Linux" not in prompt
        assert "HUD" not in prompt
        assert "CONCISENESS" not in prompt


# ---------------------------------------------------------------------------
# _build_messages
# ---------------------------------------------------------------------------


class TestBuildMessages:
    def test_text_only(self):
        msgs = _build_messages(
            text="What is 2+2?",
            history=[],
            system_prompt="You are helpful.",
        )
        assert len(msgs) == 2
        assert msgs[0] == {"role": "system", "content": "You are helpful."}
        assert msgs[1] == {"role": "user", "content": "What is 2+2?"}

    def test_with_history(self):
        history = [
            {"role": "user", "content": "Hi"},
            {"role": "assistant", "content": "Hello!"},
        ]
        msgs = _build_messages(
            text="Follow up.",
            history=history,
            system_prompt="sys",
        )
        assert len(msgs) == 4  # system + 2 history + 1 new user
        assert msgs[0]["role"] == "system"
        assert msgs[1] == {"role": "user", "content": "Hi"}
        assert msgs[2] == {"role": "assistant", "content": "Hello!"}
        assert msgs[3] == {"role": "user", "content": "Follow up."}

    def test_empty_system_prompt(self):
        msgs = _build_messages(text="Hello", history=[], system_prompt="")
        # Empty system prompt should not add a system message.
        assert len(msgs) == 1
        assert msgs[0]["role"] == "user"

    def test_with_image(self):
        msgs = _build_messages(
            text="What's in this image?",
            history=[],
            system_prompt="sys",
            image="base64data",
        )
        assert len(msgs) == 2
        user_msg = msgs[1]
        assert user_msg["role"] == "user"
        content = user_msg["content"]
        assert isinstance(content, list)
        assert len(content) == 2
        # First element is the image.
        assert content[0]["type"] == "image_url"
        assert "base64data" in content[0]["image_url"]["url"]
        assert content[0]["image_url"]["url"].startswith("data:image/png;base64,")
        # Second element is the text.
        assert content[1]["type"] == "text"
        assert content[1]["text"] == "What's in this image?"

    def test_with_file(self):
        msgs = _build_messages(
            text="Summarize this",
            history=[],
            system_prompt="sys",
            file="/tmp/notes.txt",
        )
        user_content = msgs[1]["content"]
        assert isinstance(user_content, str)
        assert "[Attached file: /tmp/notes.txt]" in user_content
        assert "Summarize this" in user_content

    def test_with_image_and_file(self):
        msgs = _build_messages(
            text="Describe",
            history=[],
            system_prompt="sys",
            image="imgdata",
            file="/tmp/f.txt",
        )
        user_msg = msgs[1]
        content = user_msg["content"]
        assert isinstance(content, list)
        # The text part should include the file prefix.
        text_part = content[1]["text"]
        assert "[Attached file: /tmp/f.txt]" in text_part
        assert "Describe" in text_part

    def test_history_not_mutated(self):
        history = [{"role": "user", "content": "original"}]
        original_history = [dict(h) for h in history]
        _build_messages(text="new", history=history, system_prompt="sys")
        assert history == original_history


# ---------------------------------------------------------------------------
# Tool call accumulation
# ---------------------------------------------------------------------------


def _make_tool_delta(index=0, tc_id=None, name=None, arguments=None):
    """Create a mock tool_call delta object (SimpleNamespace)."""
    fn = SimpleNamespace()
    fn.name = name
    fn.arguments = arguments
    tc = SimpleNamespace()
    tc.index = index
    tc.id = tc_id
    tc.function = fn
    return tc


class TestAccumulateToolCalls:
    def test_single_tool_call_in_one_chunk(self):
        acc: dict[int, dict] = {}
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, "call_1", "shell", '{"command": "ls"}'),
        ])
        assert 0 in acc
        assert acc[0]["id"] == "call_1"
        assert acc[0]["name"] == "shell"
        assert acc[0]["arguments"] == '{"command": "ls"}'

    def test_arguments_streamed_incrementally(self):
        acc: dict[int, dict] = {}
        # First chunk: id + name + partial args.
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, "call_1", "shell", '{"comma'),
        ])
        # Second chunk: more args.
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, None, None, 'nd": "ls'),
        ])
        # Third chunk: closing.
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, None, None, '"}'),
        ])
        assert acc[0]["name"] == "shell"
        assert acc[0]["arguments"] == '{"command": "ls"}'

    def test_multiple_tool_calls(self):
        acc: dict[int, dict] = {}
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, "call_1", "shell", '{"command": "ls"}'),
        ])
        _accumulate_tool_calls(acc, [
            _make_tool_delta(1, "call_2", "clipboard", '{"text": "hi"}'),
        ])
        assert len(acc) == 2
        assert acc[0]["name"] == "shell"
        assert acc[1]["name"] == "clipboard"

    def test_id_updated_on_later_chunk(self):
        acc: dict[int, dict] = {}
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, "", "shell", ""),
        ])
        _accumulate_tool_calls(acc, [
            _make_tool_delta(0, "call_late", None, '{"a": 1}'),
        ])
        assert acc[0]["id"] == "call_late"

    def test_dict_format_tool_calls(self):
        """Tool calls can also arrive as plain dicts (not objects)."""
        acc: dict[int, dict] = {}
        _accumulate_tool_calls(acc, [
            {"index": 0, "id": "call_d", "function": {"name": "web_search", "arguments": '{"q": "test"}'}},
        ])
        assert acc[0]["name"] == "web_search"
        assert acc[0]["arguments"] == '{"q": "test"}'


class TestParseToolCalls:
    def test_parses_valid_json(self):
        acc = {0: {"id": "c1", "name": "shell", "arguments": '{"command": "ls"}'}}
        result = _parse_tool_calls(acc)
        assert len(result) == 1
        assert result[0]["id"] == "c1"
        assert result[0]["name"] == "shell"
        assert result[0]["arguments"] == {"command": "ls"}

    def test_parses_empty_arguments(self):
        acc = {0: {"id": "c1", "name": "screenshot", "arguments": ""}}
        result = _parse_tool_calls(acc)
        assert result[0]["arguments"] == {}

    def test_handles_invalid_json(self):
        acc = {0: {"id": "c1", "name": "shell", "arguments": "not json{{"}}
        result = _parse_tool_calls(acc)
        assert result[0]["arguments"] == {}

    def test_preserves_order(self):
        acc = {
            2: {"id": "c3", "name": "third", "arguments": "{}"},
            0: {"id": "c1", "name": "first", "arguments": "{}"},
            1: {"id": "c2", "name": "second", "arguments": "{}"},
        }
        result = _parse_tool_calls(acc)
        assert [r["name"] for r in result] == ["first", "second", "third"]

    def test_generates_id_when_missing(self):
        acc = {0: {"id": "", "name": "shell", "arguments": "{}"}}
        result = _parse_tool_calls(acc)
        assert result[0]["id"] == "call_0"

    def test_skips_missing_name(self):
        acc = {0: {"id": "c1", "name": "", "arguments": "{}"}}
        result = _parse_tool_calls(acc)
        assert result == []

    def test_non_object_arguments_become_empty_object(self):
        acc = {0: {"id": "c1", "name": "shell", "arguments": '["bad"]'}}
        result = _parse_tool_calls(acc)
        assert result[0]["arguments"] == {}


class TestFormatToolResult:
    def test_string_result(self):
        assert _format_tool_result("ok") == "ok"

    def test_json_result(self):
        assert _format_tool_result({"ok": True}) == '{"ok": true}'

    def test_image_result_uses_data_fallback(self):
        result = _format_tool_result({
            "type": "image",
            "data": "abc",
            "media_type": "image/png",
        })
        parsed = json.loads(result)
        assert parsed["type"] == "image"
        assert parsed["base64"] == "abc"

    def test_truncates_long_result(self):
        result = _format_tool_result("x" * 20, max_chars=5)
        assert result.startswith("xxxxx")
        assert "truncated" in result


class TestWebSearchRouting:
    def test_forces_web_search_for_explicit_search_request(self):
        tools = [{"type": "function", "function": {"name": "web_search"}}]
        assert _should_force_web_search("найди в интернете qwen новости", tools, {})

    def test_does_not_force_without_tool(self):
        assert not _should_force_web_search("найди в интернете qwen новости", [], {})

    def test_can_disable_forced_web_search(self):
        tools = [{"type": "function", "function": {"name": "web_search"}}]
        assert not _should_force_web_search(
            "latest qwen news",
            tools,
            {"tools": {"force_web_search": False}},
        )


class TestPrepareMessagesForModel:
    def test_adds_no_think_for_ollama_only_in_prepared_messages(self):
        messages = [{"role": "user", "content": "hello"}]
        prepared = _prepare_messages_for_model(messages, "ollama/qwen-local", True)

        assert "/no_think" in prepared[-1]["content"]
        assert "/no_think" not in messages[-1]["content"]

    def test_ollama_converts_tool_messages_to_text(self):
        messages = [
            {"role": "assistant", "content": None, "tool_calls": [{
                "id": "forced_web_search",
                "type": "function",
                "function": {"name": "web_search", "arguments": "{}"},
            }]},
            {"role": "tool", "tool_call_id": "forced_web_search", "content": "Result"},
            {"role": "user", "content": "answer"},
        ]

        prepared = _prepare_messages_for_model(messages, "ollama/qwen-local", True)

        assert all(isinstance(message["content"], str) for message in prepared)
        assert "Tool call: web_search({})" in prepared[0]["content"]
        assert "Tool result:\nResult" in prepared[1]["content"]


# ---------------------------------------------------------------------------
# notify_error
# ---------------------------------------------------------------------------


class TestNotifyError:
    @mock.patch("aside.query.subprocess.Popen")
    def test_sends_critical_notification(self, mock_popen):
        notify_error("Something went wrong")
        mock_popen.assert_called_once()
        args = mock_popen.call_args[0][0]
        assert "notify-send" in args
        assert "-u" in args
        assert "critical" in args
        assert "Something went wrong" in args

    @mock.patch("aside.query.subprocess.Popen")
    def test_uses_aside_app_name(self, mock_popen):
        notify_error("error")
        args = mock_popen.call_args[0][0]
        assert "-a" in args
        idx = args.index("-a")
        assert args[idx + 1] == "Aside"

    @mock.patch("aside.query.subprocess.Popen", side_effect=FileNotFoundError)
    def test_handles_missing_notify_send(self, mock_popen):
        # Should not raise.
        notify_error("error")


# ---------------------------------------------------------------------------
# stream_response (mocked LiteLLM)
# ---------------------------------------------------------------------------


def _make_chunk(content=None, tool_calls=None, usage=None, model="test-model", finish_reason=None):
    """Create a mock LiteLLM streaming chunk."""
    delta = SimpleNamespace(content=content, tool_calls=tool_calls)
    choice = SimpleNamespace(delta=delta, finish_reason=finish_reason)

    chunk_usage = None
    if usage:
        chunk_usage = SimpleNamespace(
            prompt_tokens=usage.get("prompt_tokens", 0),
            completion_tokens=usage.get("completion_tokens", 0),
        )

    return SimpleNamespace(
        choices=[choice],
        model=model,
        usage=chunk_usage,
    )


def _make_usage_chunk(prompt_tokens, completion_tokens, model="test-model"):
    """Create a final usage-only chunk (no choices)."""
    return SimpleNamespace(
        choices=[],
        model=model,
        usage=SimpleNamespace(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
        ),
    )


class TestStreamResponse:
    @mock.patch("aside.query.litellm.completion")
    @mock.patch("aside.query.urllib.request.urlopen")
    def test_ollama_fast_path_streaming(self, mock_urlopen, mock_completion):
        class FakeResponse:
            def __init__(self, lines):
                self.lines = lines
                self.closed = False

            def __iter__(self):
                return iter(self.lines)

            def close(self):
                self.closed = True

        response = FakeResponse([
            b'{"model":"qwen-local","response":"Hi ","done":false}\n',
            b'{"model":"qwen-local","response":"there","done":false}\n',
            b'{"model":"qwen-local","done":true,"prompt_eval_count":7,"eval_count":2}\n',
        ])
        mock_urlopen.return_value = response

        sent = []
        mock_sock = mock.Mock()
        mock_sock.sendall = lambda data: sent.append(json.loads(data.decode().strip()))

        from aside.sentence_buffer import SentenceBuffer
        text, tool_calls, usage = stream_response(
            model="ollama/qwen-local",
            messages=[{"role": "user", "content": "hi"}],
            tools=[],
            cancel_event=None,
            overlay_sock=mock_sock,
            tts=None,
            sentence_buf=SentenceBuffer(),
            speak_on=False,
            api_base="http://localhost:11434",
            ollama_fast_path=True,
            ollama_keep_alive="1h",
            ollama_think=False,
        )

        assert text == "Hi there"
        assert tool_calls == []
        assert usage["model"] == "ollama/qwen-local"
        assert usage["input_tokens"] == 7
        assert usage["output_tokens"] == 2
        assert [m["data"] for m in sent if m.get("cmd") == "text"] == ["Hi ", "there"]
        assert response.closed
        mock_completion.assert_not_called()

        request = mock_urlopen.call_args.args[0]
        payload = json.loads(request.data.decode("utf-8"))
        assert payload["model"] == "qwen-local"
        assert payload["keep_alive"] == "1h"
        assert payload["think"] is False
        assert payload["stream"] is True

    @mock.patch("aside.query.litellm.completion")
    def test_basic_text_streaming(self, mock_completion):
        mock_completion.return_value = iter([
            _make_chunk(content="Hello "),
            _make_chunk(content="world!"),
            _make_usage_chunk(100, 50),
        ])
        from aside.sentence_buffer import SentenceBuffer
        text, tool_calls, usage = stream_response(
            model="test-model",
            messages=[{"role": "user", "content": "hi"}],
            tools=[],
            cancel_event=None,
            overlay_sock=None,
            tts=None,
            sentence_buf=SentenceBuffer(),
            speak_on=False,
        )
        assert text == "Hello world!"
        assert tool_calls == []
        assert usage["input_tokens"] == 100
        assert usage["output_tokens"] == 50

    @mock.patch("aside.query.litellm.completion")
    def test_tool_call_streaming(self, mock_completion):
        mock_completion.return_value = iter([
            _make_chunk(tool_calls=[
                _make_tool_delta(0, "call_1", "shell", '{"command":'),
            ]),
            _make_chunk(tool_calls=[
                _make_tool_delta(0, None, None, ' "ls"}'),
            ]),
            _make_usage_chunk(200, 100),
        ])
        from aside.sentence_buffer import SentenceBuffer
        text, tool_calls, usage = stream_response(
            model="test-model",
            messages=[{"role": "user", "content": "list files"}],
            tools=[{"type": "function", "function": {"name": "shell"}}],
            cancel_event=None,
            overlay_sock=None,
            tts=None,
            sentence_buf=SentenceBuffer(),
            speak_on=False,
        )
        assert text == ""
        assert len(tool_calls) == 1
        assert tool_calls[0]["name"] == "shell"
        assert tool_calls[0]["arguments"] == {"command": "ls"}

    @mock.patch("aside.query.litellm.completion")
    def test_cancellation(self, mock_completion):
        cancel = threading.Event()
        cancel.set()

        mock_completion.return_value = iter([
            _make_chunk(content="Should not accumulate"),
        ])
        from aside.sentence_buffer import SentenceBuffer
        text, tool_calls, usage = stream_response(
            model="test-model",
            messages=[],
            tools=[],
            cancel_event=cancel,
            overlay_sock=None,
            tts=None,
            sentence_buf=SentenceBuffer(),
            speak_on=False,
        )
        # Cancelled: returns empty tool_calls.
        assert tool_calls == []

    @mock.patch("aside.query.litellm.completion")
    def test_overlay_receives_text_deltas(self, mock_completion):
        mock_completion.return_value = iter([
            _make_chunk(content="chunk1"),
            _make_chunk(content="chunk2"),
        ])
        sent = []
        mock_sock = mock.Mock()
        mock_sock.sendall = lambda data: sent.append(json.loads(data.decode().strip()))

        from aside.sentence_buffer import SentenceBuffer
        stream_response(
            model="test-model",
            messages=[],
            tools=[],
            cancel_event=None,
            overlay_sock=mock_sock,
            tts=None,
            sentence_buf=SentenceBuffer(),
            speak_on=False,
        )
        text_cmds = [m for m in sent if m.get("cmd") == "text"]
        assert len(text_cmds) == 2
        assert text_cmds[0]["data"] == "chunk1"
        assert text_cmds[1]["data"] == "chunk2"

    @mock.patch("aside.query.litellm.completion")
    def test_tts_receives_sentences(self, mock_completion):
        # Stream enough text to produce a sentence.
        mock_completion.return_value = iter([
            _make_chunk(content="This is a complete sentence. "),
            _make_chunk(content="And another."),
        ])
        mock_tts = mock.Mock()
        mock_tts.speak = mock.Mock()

        from aside.sentence_buffer import SentenceBuffer
        stream_response(
            model="test-model",
            messages=[],
            tools=[],
            cancel_event=None,
            overlay_sock=None,
            tts=mock_tts,
            sentence_buf=SentenceBuffer(),
            speak_on=True,
        )
        # TTS should have been called at least once.
        assert mock_tts.speak.called

    @mock.patch("aside.query.litellm.completion")
    def test_mixed_text_and_tool_calls(self, mock_completion):
        """Response with both text content and tool calls."""
        mock_completion.return_value = iter([
            _make_chunk(content="Let me check. "),
            _make_chunk(tool_calls=[
                _make_tool_delta(0, "call_1", "shell", '{"command": "date"}'),
            ]),
            _make_usage_chunk(150, 75),
        ])
        from aside.sentence_buffer import SentenceBuffer
        text, tool_calls, usage = stream_response(
            model="test-model",
            messages=[],
            tools=[{"type": "function", "function": {"name": "shell"}}],
            cancel_event=None,
            overlay_sock=None,
            tts=None,
            sentence_buf=SentenceBuffer(),
            speak_on=False,
        )
        assert text == "Let me check. "
        assert len(tool_calls) == 1
        assert tool_calls[0]["name"] == "shell"


# ---------------------------------------------------------------------------
# NEW_CONVERSATION sentinel
# ---------------------------------------------------------------------------


class TestNewConversation:
    def test_sentinel_is_unique(self):
        assert NEW_CONVERSATION is not None
        assert NEW_CONVERSATION is not True
        assert NEW_CONVERSATION is not False

    def test_sentinel_identity(self):
        """Sentinel should be compared with `is`, not `==`."""
        assert NEW_CONVERSATION is NEW_CONVERSATION


# ---------------------------------------------------------------------------
# send_query — overlay open includes conv_id
# ---------------------------------------------------------------------------


class TestSendQueryOverlay:
    @mock.patch("aside.query.litellm.completion")
    @mock.patch("aside.query._connect_overlay")
    def test_overlay_open_includes_conv_id(self, mock_connect, mock_completion):
        """The open command sent to the overlay must include conv_id."""
        mock_completion.return_value = iter([
            _make_chunk(content="hi"),
            _make_usage_chunk(10, 5),
        ])

        sent = []
        mock_sock = mock.Mock()
        mock_sock.sendall = lambda data: sent.append(
            json.loads(data.decode().strip())
        )
        mock_connect.return_value = mock_sock

        # Minimal store mock
        store = mock.Mock()
        conv = {"id": "abc-123-def", "messages": []}
        store.get_or_create.return_value = conv

        status = mock.Mock()
        status.speak_enabled = False

        usage_log = mock.Mock()

        send_query(
            text="hello",
            conversation_id=NEW_CONVERSATION,
            config={"model": {"name": "test-model"}},
            store=store,
            status=status,
            usage_log=usage_log,
        )

        open_cmds = [m for m in sent if m.get("cmd") == "open"]
        assert len(open_cmds) == 1
        assert open_cmds[0]["conv_id"] == "abc-123-def"

    @mock.patch("aside.query.stream_response")
    @mock.patch("aside.query._connect_overlay")
    def test_mic_query_enables_tts_when_mic_tts_enabled(self, mock_connect, mock_stream):
        mock_stream.return_value = (
            "hi",
            [],
            {"model": "test-model", "input_tokens": 1, "output_tokens": 1},
        )
        mock_connect.return_value = None

        store = mock.Mock()
        conv = {"id": "mic-tts-conv", "messages": []}
        store.get_or_create.return_value = conv

        status = mock.Mock()
        status.speak_enabled = False
        usage_log = mock.Mock()
        tts = mock.Mock()
        tts._running = False

        send_query(
            text="hello",
            conversation_id=NEW_CONVERSATION,
            config={
                "model": {"name": "test-model"},
                "tts": {"mic_enabled": True},
            },
            store=store,
            status=status,
            usage_log=usage_log,
            tts=tts,
            from_mic=True,
        )

        tts.start.assert_called_once()
        assert mock_stream.call_args.kwargs["speak_on"] is True


class TestSendQueryToolCalling:
    @mock.patch("aside.query.run_tool")
    @mock.patch("aside.query.stream_response")
    @mock.patch("aside.query._connect_overlay")
    def test_executes_tool_and_continues_response(self, mock_connect, mock_stream, mock_run_tool, tmp_path):
        mock_stream.side_effect = [
            (
                "",
                [{
                    "id": "call_1",
                    "name": "memory",
                    "arguments": {"action": "recent"},
                }],
                {"model": "test-model", "input_tokens": 10, "output_tokens": 1},
            ),
            (
                "Tool result handled.",
                [],
                {"model": "test-model", "input_tokens": 20, "output_tokens": 5},
            ),
        ]
        mock_run_tool.return_value = "Last memories: none"

        sent = []
        mock_sock = mock.Mock()
        mock_sock.sendall = lambda data: sent.append(
            json.loads(data.decode().strip())
        )
        mock_connect.return_value = mock_sock

        store = mock.Mock()
        conv = {"id": "tool-conv", "messages": []}
        store.get_or_create.return_value = conv

        status = mock.Mock()
        status.speak_enabled = False
        usage_log = mock.Mock()

        result_id = send_query(
            text="show memories",
            conversation_id=NEW_CONVERSATION,
            config={"model": {"name": "test-model"}, "tools": {"max_rounds": 3}},
            store=store,
            status=status,
            usage_log=usage_log,
            plugin_dirs=[tmp_path],
            tools=[{"type": "function", "function": {"name": "memory"}}],
        )

        assert result_id == "tool-conv"
        mock_run_tool.assert_called_once_with(
            "memory",
            {"action": "recent"},
            [tmp_path],
        )
        assert mock_stream.call_count == 2

        second_messages = mock_stream.call_args_list[1].kwargs["messages"]
        assert second_messages[-1] == {
            "role": "tool",
            "tool_call_id": "call_1",
            "content": "Last memories: none",
        }

        assert conv["messages"][1]["role"] == "assistant"
        assert conv["messages"][1]["tool_calls"][0]["function"]["name"] == "memory"
        assert conv["messages"][2]["role"] == "tool"
        assert conv["messages"][3] == {
            "role": "assistant",
            "content": "Tool result handled.",
        }
        assert any(m.get("cmd") == "thinking" for m in sent)

    @mock.patch("aside.query.run_tool")
    @mock.patch("aside.query.stream_response")
    @mock.patch("aside.query._connect_overlay")
    def test_tool_round_limit_adds_tool_results(self, mock_connect, mock_stream, mock_run_tool):
        mock_stream.return_value = (
            "",
            [{
                "id": "call_1",
                "name": "memory",
                "arguments": {"action": "recent"},
            }],
            {"model": "test-model", "input_tokens": 1, "output_tokens": 1},
        )

        sent = []
        mock_sock = mock.Mock()
        mock_sock.sendall = lambda data: sent.append(
            json.loads(data.decode().strip())
        )
        mock_connect.return_value = mock_sock

        store = mock.Mock()
        conv = {"id": "limit-conv", "messages": []}
        store.get_or_create.return_value = conv

        status = mock.Mock()
        status.speak_enabled = False
        usage_log = mock.Mock()

        send_query(
            text="loop",
            conversation_id=NEW_CONVERSATION,
            config={"model": {"name": "test-model"}, "tools": {"max_rounds": 0}},
            store=store,
            status=status,
            usage_log=usage_log,
            tools=[{"type": "function", "function": {"name": "memory"}}],
        )

        mock_run_tool.assert_not_called()
        assert conv["messages"][-1]["role"] == "tool"
        assert "Stopped after 0 tool-call rounds." in conv["messages"][-1]["content"]
        assert any(
            m.get("cmd") == "replace" and "Stopped after 0 tool-call rounds." in m.get("data", "")
            for m in sent
        )

    @mock.patch("aside.query.run_tool")
    @mock.patch("aside.query.stream_response")
    @mock.patch("aside.query._connect_overlay")
    def test_forces_web_search_before_first_model_call(self, mock_connect, mock_stream, mock_run_tool, tmp_path):
        mock_stream.return_value = (
            "Final answer.",
            [],
            {"model": "ollama/qwen-local", "input_tokens": 1, "output_tokens": 1},
        )
        mock_run_tool.return_value = "Search result"

        sent = []
        mock_sock = mock.Mock()
        mock_sock.sendall = lambda data: sent.append(
            json.loads(data.decode().strip())
        )
        mock_connect.return_value = mock_sock

        store = mock.Mock()
        conv = {"id": "search-conv", "messages": []}
        store.get_or_create.return_value = conv

        status = mock.Mock()
        status.speak_enabled = False
        usage_log = mock.Mock()

        send_query(
            text="найди в интернете qwen новости",
            conversation_id=NEW_CONVERSATION,
            config={
                "model": {"name": "ollama/qwen-local", "disable_thinking": True},
                "tools": {"max_rounds": 3, "force_web_search": True},
            },
            store=store,
            status=status,
            usage_log=usage_log,
            plugin_dirs=[tmp_path],
            tools=[{"type": "function", "function": {"name": "web_search"}}],
        )

        mock_run_tool.assert_called_once_with(
            "web_search",
            {"query": "найди в интернете qwen новости", "max_results": 5},
            [tmp_path],
        )
        first_model_messages = mock_stream.call_args.kwargs["messages"]
        assert any("Tool result:\nSearch result" in m["content"] for m in first_model_messages)
        assert "/no_think" in first_model_messages[-1]["content"]
        assert all("/no_think" not in str(m.get("content")) for m in conv["messages"])
