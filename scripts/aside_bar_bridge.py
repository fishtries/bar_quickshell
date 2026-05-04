from __future__ import annotations

import json
import os
import signal
import socket
import sys
import threading
from pathlib import Path


def runtime_path(name: str) -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / name


sock_path = runtime_path("aside-overlay.sock")
stop_event = threading.Event()
print_lock = threading.Lock()


def emit(payload: dict) -> None:
    with print_lock:
        print(json.dumps(payload, ensure_ascii=False), flush=True)


def handle_connection(conn: socket.socket) -> None:
    buffer = b""
    try:
        while not stop_event.is_set():
            chunk = conn.recv(4096)
            if not chunk:
                break
            buffer += chunk
            while b"\n" in buffer:
                raw, buffer = buffer.split(b"\n", 1)
                process_line(raw)
        if buffer.strip():
            process_line(buffer)
    except OSError as exc:
        emit({"type": "bridge_error", "error": str(exc)})
    finally:
        try:
            conn.close()
        except OSError:
            pass


def process_line(raw: bytes) -> None:
    text = raw.decode("utf-8", errors="replace").strip()
    if not text:
        return
    try:
        command = json.loads(text)
    except json.JSONDecodeError:
        emit({"type": "bridge_error", "error": "invalid overlay json", "raw": text})
        return
    emit({"type": "overlay", "data": command})


def stop(*_: object) -> None:
    stop_event.set()
    try:
        socket.socket(socket.AF_UNIX, socket.SOCK_STREAM).connect(str(sock_path))
    except OSError:
        pass


def main() -> int:
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    try:
        sock_path.unlink()
    except FileNotFoundError:
        pass
    except OSError as exc:
        emit({"type": "bridge_error", "error": f"cannot remove socket: {exc}"})

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        server.bind(str(sock_path))
        os.chmod(str(sock_path), 0o600)
        server.listen(16)
        server.settimeout(0.5)
    except OSError as exc:
        emit({"type": "bridge_error", "error": f"cannot bind overlay socket: {exc}"})
        return 1

    emit({"type": "ready", "socket": str(sock_path)})

    try:
        while not stop_event.is_set():
            try:
                conn, _ = server.accept()
            except socket.timeout:
                continue
            except OSError as exc:
                if not stop_event.is_set():
                    emit({"type": "bridge_error", "error": str(exc)})
                break
            threading.Thread(target=handle_connection, args=(conn,), daemon=True).start()
    finally:
        try:
            server.close()
        except OSError:
            pass
        try:
            if sock_path.exists():
                sock_path.unlink()
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
