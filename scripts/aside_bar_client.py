from __future__ import annotations

import argparse
import json
import os
import socket
import sys
from pathlib import Path


def runtime_path(name: str) -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / name


def state_path(name: str) -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))) / "aside" / name


def send_daemon(payload: dict) -> None:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(str(runtime_path("aside.sock")))
        sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        sock.shutdown(socket.SHUT_WR)
    finally:
        sock.close()


def print_json(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def status() -> int:
    path = state_path("status.json")
    if not path.is_file():
        print_json({"ok": False, "error": "aside daemon is not running"})
        return 1
    try:
        payload = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        print_json({"ok": False, "error": str(exc)})
        return 1
    payload["ok"] = True
    print_json(payload)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    query = sub.add_parser("query")
    query.add_argument("text")
    query.add_argument("--conversation-id", default="")
    query.add_argument("--new", action="store_true")

    mic = sub.add_parser("mic")
    mic.add_argument("--conversation-id", default="")
    mic.add_argument("--new", action="store_true")

    sub.add_parser("cancel")
    sub.add_parser("stop-tts")
    sub.add_parser("toggle-tts")
    sub.add_parser("status")

    args = parser.parse_args()

    try:
        if args.command == "query":
            conversation_id = "__new__" if args.new else (args.conversation_id or None)
            send_daemon({"action": "query", "text": args.text, "conversation_id": conversation_id})
        elif args.command == "mic":
            conversation_id = "__new__" if args.new else (args.conversation_id or None)
            send_daemon({"action": "query", "mic": True, "conversation_id": conversation_id})
        elif args.command == "cancel":
            send_daemon({"action": "cancel"})
        elif args.command == "stop-tts":
            send_daemon({"action": "stop_tts"})
        elif args.command == "toggle-tts":
            send_daemon({"action": "toggle_tts"})
        elif args.command == "status":
            return status()
    except (ConnectionRefusedError, FileNotFoundError, OSError) as exc:
        print_json({"ok": False, "error": f"aside daemon is not available: {exc}"})
        return 1

    print_json({"ok": True})
    return 0


if __name__ == "__main__":
    sys.exit(main())
