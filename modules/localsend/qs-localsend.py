import argparse
import base64
import concurrent.futures
import errno
import getpass
import hashlib
import http.client
import ipaddress
import json
import mimetypes
import os
import platform
import re
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PROTOCOL_VERSION = "2.1"
DEFAULT_PORT = 53317
DEFAULT_GROUP = "224.0.0.167"
CHUNK_SIZE = 1024 * 256
_print_lock = threading.Lock()
TLS_DIR = os.path.expanduser("~/.cache/quickshell/localsend")
TLS_CERT_PATH = os.path.join(TLS_DIR, "cert.pem")
TLS_KEY_PATH = os.path.join(TLS_DIR, "key.pem")
CONFIRM_DIR = os.path.join(TLS_DIR, "confirmations")
DEFAULT_AUTO_ACCEPT_IPS = ["192.168.1.112"]


def emit(payload):
    try:
        with _print_lock:
            print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), flush=True)
    except BrokenPipeError:
        pass


def confirmation_path(request_id):
    safe = "".join(ch for ch in request_id if ch.isalnum() or ch in ("-", "_"))
    if not safe:
        raise RuntimeError("Invalid confirmation request id")
    return os.path.join(CONFIRM_DIR, f"{safe}.json")


def normalize_ip(value):
    text = str(value or "").strip()
    if not text:
        return ""
    try:
        address = ipaddress.ip_address(text)
        if getattr(address, "ipv4_mapped", None):
            address = address.ipv4_mapped
        return str(address)
    except ValueError:
        return text


def is_disconnected_client_error(exc):
    if isinstance(exc, (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, ssl.SSLEOFError)):
        return True
    return isinstance(exc, OSError) and exc.errno in (errno.EPIPE, errno.ECONNRESET, errno.ECONNABORTED)


def process_cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as handle:
            return [part.decode("utf-8", "replace") for part in handle.read().split(b"\0") if part]
    except OSError:
        return []


def process_ppid(pid):
    try:
        with open(f"/proc/{pid}/status", "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if line.startswith("PPid:"):
                    return int(line.split(":", 1)[1].strip() or 0)
    except OSError:
        return 0
    return 0


def listening_pids(port):
    try:
        result = subprocess.run(["ss", "-ltnp", f"sport = :{int(port)}"], check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except Exception:
        return []
    return sorted({int(pid) for pid in re.findall(r"pid=(\d+)", result.stdout or "") if int(pid) != os.getpid()})


def is_quickshell_receiver(pid):
    cmdline = process_cmdline(pid)
    joined = "\0".join(cmdline)
    return "qs-localsend.py" in joined and "receive" in cmdline


def stop_stale_receivers(port):
    stale = [pid for pid in listening_pids(port) if is_quickshell_receiver(pid) and process_ppid(pid) == 1]
    for pid in stale:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    deadline = time.monotonic() + 2
    while stale and time.monotonic() < deadline:
        remaining = set(listening_pids(port))
        if not any(pid in remaining for pid in stale):
            return stale
        time.sleep(0.1)
    remaining = set(listening_pids(port))
    for pid in stale:
        if pid in remaining:
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass
    return stale


def fingerprint():
    raw = f"{getpass.getuser()}@{socket.gethostname()}:{platform.machine()}"
    return hashlib.sha256(raw.encode("utf-8", "replace")).hexdigest()


def certificate_fingerprint(cert_path):
    with open(cert_path, "r", encoding="utf-8") as handle:
        lines = [
            line.strip()
            for line in handle
            if line.strip() and not line.startswith("-----")
        ]
    der = base64.b64decode("".join(lines))
    return hashlib.sha256(der).hexdigest().upper()


def ensure_tls_material(cert_path=TLS_CERT_PATH, key_path=TLS_KEY_PATH):
    cert_path = os.path.abspath(os.path.expanduser(cert_path))
    key_path = os.path.abspath(os.path.expanduser(key_path))
    if os.path.isfile(cert_path) and os.path.isfile(key_path):
        return cert_path, key_path, certificate_fingerprint(cert_path)
    if not shutil.which("openssl"):
        raise RuntimeError("openssl is required for HTTPS receive certificate generation")
    os.makedirs(os.path.dirname(cert_path), exist_ok=True)
    os.makedirs(os.path.dirname(key_path), exist_ok=True)
    result = subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-sha256",
            "-days",
            "3650",
            "-nodes",
            "-subj",
            "/CN=LocalSend User/O=/OU=/L=/ST=/C=/",
            "-keyout",
            key_path,
            "-out",
            cert_path,
        ],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout or "failed to generate HTTPS certificate").strip())
    os.chmod(key_path, 0o600)
    return cert_path, key_path, certificate_fingerprint(cert_path)


def alias_default():
    return f"QuickShell {socket.gethostname()}"


def protocol_url(protocol, ip, port, version, path, query=None):
    api_path = f"/api/localsend/v{1 if version == '1.0' else 2}/{path}"
    if version == "1.0":
        api_path = api_path.replace("prepare-upload", "send-request").replace("upload", "send")
    return urllib.parse.urlunparse((protocol, f"{ip}:{port}", api_path, "", urllib.parse.urlencode(query or {}), ""))


def local_ipv4_addresses(include_prefix=False):
    addresses = []
    try:
        result = subprocess.run(["ip", "-4", "-o", "addr", "show", "scope", "global"], check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) < 4:
                continue
            interface = parts[1]
            cidr = parts[3]
            address = cidr.split("/", 1)[0]
            if address and not address.startswith("127."):
                if include_prefix:
                    addresses.append((interface, address, cidr))
                else:
                    addresses.append((interface, address))
    except Exception:
        pass
    if not addresses:
        try:
            hostname = socket.gethostname()
            for item in socket.getaddrinfo(hostname, None, socket.AF_INET, socket.SOCK_DGRAM):
                address = item[4][0]
                if address and not address.startswith("127."):
                    if include_prefix:
                        addresses.append(("", address, f"{address}/24"))
                    else:
                        addresses.append(("", address))
        except Exception:
            pass
    unique = []
    seen = set()
    for item in addresses:
        interface = item[0]
        address = item[1]
        if address in seen:
            continue
        seen.add(address)
        unique.append(item)
    return unique


def https_context(cert_path=None, key_path=None):
    ctx = ssl._create_unverified_context()
    if cert_path and key_path:
        ctx.load_cert_chain(certfile=cert_path, keyfile=key_path)
    return ctx


def request_json(protocol, ip, port, version, path, payload=None, query=None, timeout=180, cert_path=None, key_path=None):
    url = protocol_url(protocol, ip, port, version, path, query)
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="GET" if payload is None else "POST")
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    ctx = https_context(cert_path, key_path) if protocol == "https" else None
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as response:
            body = response.read()
            if not body:
                return response.status, None
            return response.status, json.loads(body.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read()
        message = body.decode("utf-8", "replace") if body else ""
        raise RuntimeError(f"HTTP {exc.code}: {message}") from exc


def probe(args):
    ports = args.port or [DEFAULT_PORT]
    protocols = args.protocol or ["http", "https"]
    versions = args.version or [PROTOCOL_VERSION, "1.0"]
    emit({"type": "probe_started", "ip": args.ip, "ports": ports, "protocols": protocols, "versions": versions})
    found = 0
    for port in ports:
        tcp_ok = False
        try:
            with socket.create_connection((args.ip, port), timeout=args.timeout):
                tcp_ok = True
            emit({"type": "probe_tcp", "status": "open", "ip": args.ip, "port": port})
        except Exception as exc:
            emit({"type": "probe_tcp", "status": "error", "ip": args.ip, "port": port, "message": str(exc)})
        if not tcp_ok and not args.force_http:
            continue
        for protocol in protocols:
            for version in versions:
                url = protocol_url(protocol, args.ip, port, version, "info")
                try:
                    status, body = request_json(protocol, args.ip, port, version, "info", timeout=args.timeout)
                    emit({"type": "probe_http", "status": "ok", "ip": args.ip, "port": port, "protocol": protocol, "version": version, "httpStatus": status, "url": url, "body": body})
                    if isinstance(body, dict):
                        device = parse_device(body, args.ip, port)
                        device["protocol"] = protocol
                        device["version"] = version
                        emit(device)
                    found += 1
                except Exception as exc:
                    emit({"type": "probe_http", "status": "error", "ip": args.ip, "port": port, "protocol": protocol, "version": version, "url": url, "message": str(exc)})
    emit({"type": "probe_finished", "count": found})
    return 0 if found else 1


def probe_device(ip, port, timeout):
    try:
        with socket.create_connection((ip, port), timeout=min(timeout, 0.5)):
            pass
    except Exception:
        return None
    for protocol in ("https", "http"):
        for version in (PROTOCOL_VERSION, "1.0"):
            try:
                status, body = request_json(protocol, ip, port, version, "info", timeout=timeout)
                if status == 200 and isinstance(body, dict) and body.get("alias"):
                    device = parse_device(body, ip, port)
                    device["protocol"] = protocol
                    device["version"] = body.get("version") or version
                    return device
            except Exception:
                pass
    return None


def local_subnet_hosts(max_hosts=512):
    hosts = []
    for interface, address, cidr in local_ipv4_addresses(True):
        if interface.startswith(("tun", "wg", "tailscale", "docker", "br-", "veth")):
            continue
        try:
            network = ipaddress.ip_interface(cidr).network
        except ValueError:
            continue
        if network.num_addresses > max_hosts:
            continue
        for host in network.hosts():
            host_text = str(host)
            if host_text != address:
                hosts.append(host_text)
    return hosts


def subnet_scan(args, seen):
    hosts = args.probe_ip or local_subnet_hosts()
    found = []
    if not hosts:
        return found
    if args.debug:
        emit({"type": "debug", "subnetProbeCount": len(hosts), "port": args.port})
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.probe_workers) as executor:
        futures = {executor.submit(probe_device, host, args.port, args.probe_timeout): host for host in hosts}
        for future in concurrent.futures.as_completed(futures):
            try:
                device = future.result()
            except Exception:
                continue
            if not device:
                continue
            key = device.get("fingerprint") or f"{device['ip']}:{device['port']}"
            if key in seen:
                continue
            seen.add(key)
            found.append(device)
    return found


def autodetect_target(args):
    if args.protocol != "auto" and args.version != "auto":
        return
    device = probe_device(args.ip, args.port, min(args.prepare_timeout, 3))
    if not device:
        raise RuntimeError(f"Could not connect to LocalSend at {args.ip}:{args.port}. Make sure the app is open, receiving is enabled, and both devices are on the same Wi-Fi.")
    if args.protocol == "auto":
        args.protocol = device.get("protocol") or "https"
    if args.version == "auto":
        args.version = device.get("version") or PROTOCOL_VERSION
    if not args.name:
        args.name = device.get("name") or device.get("alias") or args.ip


def file_metadata(path):
    stat = os.stat(path)
    mime = mimetypes.guess_type(path)[0] or "application/octet-stream"
    modified = datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat()
    accessed = datetime.fromtimestamp(stat.st_atime, timezone.utc).isoformat()
    file_id = str(uuid.uuid4())
    return file_id, {
        "id": file_id,
        "fileName": os.path.basename(path),
        "size": stat.st_size,
        "fileType": mime,
        "metadata": {
            "modified": modified,
            "accessed": accessed,
        },
    }


def make_info(alias, port=DEFAULT_PORT, protocol="http", download=False, fingerprint_value=None):
    return {
        "alias": alias,
        "version": PROTOCOL_VERSION,
        "deviceModel": platform.node() or "Linux",
        "deviceType": "desktop",
        "fingerprint": fingerprint_value or fingerprint(),
        "port": port,
        "protocol": protocol,
        "download": download,
    }


def make_multicast(alias, port, protocol, announcement, fingerprint_value=None):
    data = make_info(alias, port, protocol, False, fingerprint_value)
    data["announcement"] = announcement
    data["announce"] = announcement
    return data


def send_multicast(alias, port, group, protocol="http", announcement=True, advertise_port=None, interfaces=None, fingerprint_value=None):
    payload = json.dumps(make_multicast(alias, advertise_port or port, protocol, announcement, fingerprint_value), separators=(",", ":")).encode("utf-8")
    targets = interfaces if interfaces is not None else local_ipv4_addresses()
    if not targets:
        targets = [("", None)]
    errors = []
    for _interface, address in targets:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
        try:
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
            if address:
                sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(address))
            sock.sendto(payload, (group, port))
        except OSError as exc:
            errors.append(exc)
        finally:
            sock.close()
    if errors and len(errors) == len(targets):
        raise errors[0]


def udp_socket(group, port):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except OSError:
            pass
    sock.bind(("", port))
    joined = False
    for _interface, address in local_ipv4_addresses():
        try:
            membership = socket.inet_aton(group) + socket.inet_aton(address)
            sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
            joined = True
        except OSError:
            pass
    if not joined:
        membership = socket.inet_aton(group) + socket.inet_aton("0.0.0.0")
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
    return sock


def parse_device(dto, ip, fallback_port):
    protocol = dto.get("protocol") or "https"
    port = int(dto.get("port") or fallback_port)
    return {
        "type": "device",
        "name": dto.get("alias") or ip,
        "alias": dto.get("alias") or ip,
        "ip": ip,
        "port": port,
        "protocol": protocol,
        "version": dto.get("version") or "1.0",
        "os": dto.get("deviceType") or "desktop",
        "deviceType": dto.get("deviceType") or "desktop",
        "deviceModel": dto.get("deviceModel") or "",
        "fingerprint": dto.get("fingerprint") or "",
        "download": bool(dto.get("download") or False),
    }


def scan_register_handler_factory(alias, discovered, seen, lock, fallback_port):
    class Handler(BaseHTTPRequestHandler):
        server_version = "QuickShellLocalSendScan/1.0"

        def log_message(self, _format, *_args):
            return

        def json_response(self, status, body=None):
            encoded = b"" if body is None else json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            self.send_response(status)
            if body is not None:
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            if encoded:
                self.wfile.write(encoded)

        def read_json(self):
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0:
                return {}
            return json.loads(self.rfile.read(length).decode("utf-8"))

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path in ("/api/localsend/v1/info", "/api/localsend/v2/info"):
                self.json_response(200, make_info(alias, fallback_port, "http", False))
                return
            self.json_response(404, {"message": "Not found"})

        def do_POST(self):
            parsed = urllib.parse.urlparse(self.path)
            if parsed.path not in ("/api/localsend/v1/register", "/api/localsend/v2/register"):
                self.json_response(404, {"message": "Not found"})
                return
            try:
                dto = self.read_json()
                device = parse_device(dto, self.client_address[0], fallback_port)
                key = device.get("fingerprint") or f"{device['ip']}:{device['port']}"
                with lock:
                    if key not in seen:
                        seen.add(key)
                        discovered.append(device)
                self.json_response(200, make_info(alias, fallback_port, "http", False))
            except Exception as exc:
                self.json_response(400, {"message": str(exc)})

    return Handler


def scan(args):
    seen = set()
    discovered = []
    discovered_lock = threading.Lock()
    interfaces = local_ipv4_addresses()
    if args.debug:
        emit({"type": "debug", "interfaces": [{"name": name, "address": address} for name, address in interfaces]})
    register_server = None
    register_thread = None
    advertise_port = args.port
    if args.tcp_register:
        try:
            register_server = ThreadingHTTPServer(("", 0), scan_register_handler_factory(args.alias, discovered, seen, discovered_lock, args.port))
            advertise_port = register_server.server_address[1]
            register_thread = threading.Thread(target=register_server.serve_forever, daemon=True)
            register_thread.start()
        except OSError as exc:
            emit({"type": "warning", "message": f"TCP discovery disabled: {exc}"})
    own = fingerprint()
    sock = udp_socket(args.group, args.port)
    sock.settimeout(0.2)
    emit({"type": "scan_started"})
    started = time.monotonic()
    next_announce = started
    announces = 0
    try:
        while time.monotonic() - started < args.timeout:
            now = time.monotonic()
            if announces < 3 and now >= next_announce:
                try:
                    send_multicast(args.alias, args.port, args.group, args.protocol, True, advertise_port, interfaces)
                except OSError as exc:
                    emit({"type": "warning", "message": str(exc)})
                announces += 1
                next_announce = now + (0.35 if announces == 1 else 0.8)
            with discovered_lock:
                pending = list(discovered)
                discovered.clear()
            for device in pending:
                emit(device)
            try:
                data, addr = sock.recvfrom(65535)
            except socket.timeout:
                continue
            try:
                dto = json.loads(data.decode("utf-8"))
            except Exception:
                continue
            if dto.get("fingerprint") == own:
                continue
            device = parse_device(dto, addr[0], args.port)
            key = device.get("fingerprint") or f"{device['ip']}:{device['port']}"
            with discovered_lock:
                if key in seen:
                    continue
                seen.add(key)
            emit(device)
    finally:
        with discovered_lock:
            pending = list(discovered)
            discovered.clear()
        for device in pending:
            emit(device)
        sock.close()
        if register_server:
            register_server.shutdown()
            register_server.server_close()
        if register_thread:
            register_thread.join(timeout=0.5)
    if args.probe_subnet and len(seen) == 0:
        for device in subnet_scan(args, seen):
            emit(device)
    emit({"type": "scan_finished", "count": len(seen)})


def prepare_upload(args, files):
    file_map = {}
    paths = {}
    for path in files:
        real_path = os.path.abspath(os.path.expanduser(path))
        file_id, dto = file_metadata(real_path)
        file_map[file_id] = dto
        paths[file_id] = real_path
    cert_path = None
    key_path = None
    fingerprint_value = None
    if args.own_protocol == "https":
        cert_path = getattr(args, "_cert_path", None)
        key_path = getattr(args, "_key_path", None)
        fingerprint_value = getattr(args, "_fingerprint", None)
        if not cert_path or not key_path or not fingerprint_value:
            cert_path, key_path, fingerprint_value = ensure_tls_material(args.cert, args.key)
            args._cert_path = cert_path
            args._key_path = key_path
            args._fingerprint = fingerprint_value
    payload = {
        "info": make_info(args.alias, args.own_port, args.own_protocol, False, fingerprint_value),
        "files": file_map,
    }
    query = {"pin": args.pin} if args.pin else None
    status, body = request_json(args.protocol, args.ip, args.port, args.version, "prepare-upload", payload, query, args.prepare_timeout, cert_path, key_path)
    if status == 204:
        return None, {}, file_map, paths
    if args.version == "1.0":
        return None, body or {}, file_map, paths
    return body.get("sessionId"), body.get("files") or {}, file_map, paths


def connection_for(protocol, ip, port, timeout, cert_path=None, key_path=None):
    if protocol == "https":
        return http.client.HTTPSConnection(ip, port, timeout=timeout, context=https_context(cert_path, key_path))
    return http.client.HTTPConnection(ip, port, timeout=timeout)


def upload_file(args, session_id, file_id, token, path, dto, overall):
    query = {"fileId": file_id, "token": token}
    if args.version != "1.0":
        query["sessionId"] = session_id
    endpoint = "/api/localsend/v1/send" if args.version == "1.0" else "/api/localsend/v2/upload"
    url_path = endpoint + "?" + urllib.parse.urlencode(query)
    size = dto["size"]
    cert_path = getattr(args, "_cert_path", None) if args.own_protocol == "https" else None
    key_path = getattr(args, "_key_path", None) if args.own_protocol == "https" else None
    conn = connection_for(args.protocol, args.ip, args.port, args.upload_timeout, cert_path, key_path)
    sent_for_file = 0
    last_emit = 0.0
    try:
        conn.putrequest("POST", url_path)
        conn.putheader("Host", f"{args.ip}:{args.port}")
        conn.putheader("Content-Type", dto["fileType"])
        conn.putheader("Content-Length", str(size))
        conn.putheader("Connection", "close")
        conn.endheaders()
        with open(path, "rb") as handle:
            while True:
                chunk = handle.read(CHUNK_SIZE)
                if not chunk:
                    break
                conn.send(chunk)
                sent_for_file += len(chunk)
                overall["sent"] += len(chunk)
                now = time.monotonic()
                if now - last_emit > 0.08 or sent_for_file == size:
                    last_emit = now
                    total = max(overall["total"], 1)
                    emit({
                        "type": "progress",
                        "direction": "send",
                        "status": "sending",
                        "peer": args.name or args.ip,
                        "fileName": dto["fileName"],
                        "fileIndex": overall["index"],
                        "fileCount": overall["count"],
                        "progress": min(1.0, overall["sent"] / total),
                        "fileProgress": 1.0 if size == 0 else min(1.0, sent_for_file / size),
                        "sentBytes": overall["sent"],
                        "totalBytes": overall["total"],
                        "fileBytesSent": sent_for_file,
                        "fileSize": size,
                    })
        response = conn.getresponse()
        body = response.read().decode("utf-8", "replace")
        if response.status != 200:
            raise RuntimeError(f"HTTP {response.status}: {body}")
    finally:
        conn.close()


def send(args):
    selected_files = (args.file or []) + (args.files or [])
    files = [os.path.abspath(os.path.expanduser(path)) for path in selected_files]
    files = [path for path in files if os.path.isfile(path)]
    if not files:
        emit({"type": "error", "message": "No readable files selected"})
        return 2
    try:
        autodetect_target(args)
        if args.own_protocol == "https":
            args._cert_path, args._key_path, args._fingerprint = ensure_tls_material(args.cert, args.key)
        total_size = sum(os.path.getsize(path) for path in files)
        emit({
            "type": "status",
            "direction": "send",
            "status": "preparing",
            "peer": args.name or args.ip,
            "fileCount": len(files),
            "totalBytes": total_size,
            "progress": 0,
        })
        session_id, tokens, file_map, paths = prepare_upload(args, files)
        if not tokens:
            emit({"type": "error", "direction": "send", "status": "error", "peer": args.name or args.ip, "message": "No files were accepted by recipient"})
            return 1
        accepted_total = sum(file_map[file_id]["size"] for file_id in tokens.keys() if file_id in file_map)
        overall = {"sent": 0, "total": accepted_total, "count": len(tokens), "index": 0}
        for file_id, token in tokens.items():
            if file_id not in paths:
                continue
            overall["index"] += 1
            upload_file(args, session_id, file_id, token, paths[file_id], file_map[file_id], overall)
        emit({
            "type": "finished",
            "direction": "send",
            "status": "finished",
            "peer": args.name or args.ip,
            "fileCount": len(tokens),
            "sentBytes": overall["sent"],
            "totalBytes": accepted_total,
            "progress": 1,
        })
        return 0
    except Exception as exc:
        emit({"type": "error", "direction": "send", "status": "error", "peer": args.name or args.ip, "message": str(exc)})
        return 1


def normalize_picker_path(value):
    text = value.strip()
    if text.startswith("file://"):
        return urllib.parse.unquote(urllib.parse.urlparse(text).path)
    return text


def pick_files(_args):
    commands = []
    if shutil.which("kdialog"):
        commands.append(["kdialog", "--getopenfilename", os.path.expanduser("~"), "*", "--multiple", "--separate-output"])
    if shutil.which("zenity"):
        commands.append(["zenity", "--file-selection", "--multiple", "--separator=\n"])
    if shutil.which("yad"):
        commands.append(["yad", "--file-selection", "--multiple", "--separator=\n"])
    if not commands:
        emit({"type": "error", "message": "No file picker found: install kdialog, zenity, or yad"})
        return 1
    for command in commands:
        try:
            result = subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except Exception as exc:
            emit({"type": "warning", "message": str(exc)})
            continue
        if result.returncode != 0:
            emit({"type": "cancelled"})
            return 0
        files = [normalize_picker_path(line) for line in result.stdout.splitlines() if normalize_picker_path(line)]
        files = [path for path in files if os.path.isfile(path)]
        emit({"type": "files", "files": files})
        return 0
    emit({"type": "error", "message": "Could not open file picker"})
    return 1


class ReceiveState:
    def __init__(self, args):
        self.args = args
        self.sessions = {}
        self.lock = threading.Lock()
        self.cert_path = None
        self.key_path = None
        self.fingerprint = fingerprint()
        self.auto_accept_ips = {normalize_ip(item) for item in (args.auto_accept_ip or [])}

    def info(self):
        return make_info(self.args.alias, self.args.port, self.args.protocol, False, self.fingerprint)

    def request_confirmation(self, sender_ip, payload):
        sender_ip = normalize_ip(sender_ip)
        files = payload.get("files") or {}
        total = sum(int((item or {}).get("size") or 0) for item in files.values())
        sender = (payload.get("info") or {}).get("alias") or sender_ip
        if sender_ip in self.auto_accept_ips:
            return True
        request_id = str(uuid.uuid4())
        path = confirmation_path(request_id)
        os.makedirs(CONFIRM_DIR, exist_ok=True)
        try:
            os.unlink(path)
        except FileNotFoundError:
            pass
        emit({"type": "incoming_confirmation", "direction": "receive", "status": "confirming", "id": request_id, "peer": sender, "ip": sender_ip, "fileCount": len(files), "totalBytes": total, "files": list(files.values()), "progress": 0})
        deadline = time.monotonic() + self.args.confirm_timeout
        while time.monotonic() < deadline:
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    decision = json.load(handle)
                try:
                    os.unlink(path)
                except FileNotFoundError:
                    pass
                return decision.get("accepted") is True
            except FileNotFoundError:
                time.sleep(0.1)
            except Exception:
                return False
        emit({"type": "error", "direction": "receive", "status": "error", "peer": sender, "message": "Incoming transfer confirmation timed out"})
        return False

    def create_session(self, sender_ip, payload):
        session_id = str(uuid.uuid4())
        files = payload.get("files") or {}
        tokens = {file_id: str(uuid.uuid4()) for file_id in files.keys()}
        with self.lock:
            self.sessions[session_id] = {
                "sender_ip": sender_ip,
                "files": files,
                "tokens": tokens,
                "received": {},
                "created": time.time(),
                "sender": payload.get("info") or {},
            }
        total = sum(int((item or {}).get("size") or 0) for item in files.values())
        sender = (payload.get("info") or {}).get("alias") or sender_ip
        emit({"type": "incoming", "direction": "receive", "status": "waiting", "peer": sender, "fileCount": len(files), "totalBytes": total, "progress": 0})
        return session_id, tokens

    def find_session(self, session_id, file_id, token):
        with self.lock:
            if session_id:
                session = self.sessions.get(session_id)
                if session and session["tokens"].get(file_id) == token:
                    return session_id, session
            for candidate_id, session in self.sessions.items():
                if session["tokens"].get(file_id) == token:
                    return candidate_id, session
        return None, None

    def mark_received(self, session_id, file_id, count):
        with self.lock:
            session = self.sessions.get(session_id)
            if not session:
                return False, 0, 0
            session["received"][file_id] = count
            total = sum(int((item or {}).get("size") or 0) for item in session["files"].values())
            received = sum(session["received"].values())
            finished = len(session["received"]) >= len(session["tokens"])
            return finished, received, total


def safe_destination(base_dir, name):
    cleaned = name.replace("\\", "/")
    parts = [part for part in cleaned.split("/") if part not in ("", ".", "..")]
    if not parts:
        parts = ["localsend-file"]
    return os.path.join(base_dir, *parts)


def receive_handler_factory(state):
    class Handler(BaseHTTPRequestHandler):
        server_version = "QuickShellLocalSend/1.0"

        def log_message(self, _format, *_args):
            return

        def json_response(self, status, body=None):
            encoded = b"" if body is None else json.dumps(body, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
            try:
                self.send_response(status)
                if body is not None:
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(encoded)))
                self.end_headers()
                if encoded:
                    self.wfile.write(encoded)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, ssl.SSLEOFError):
                return

        def read_json(self):
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0:
                return {}
            return json.loads(self.rfile.read(length).decode("utf-8"))

        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            if state.args.debug_http:
                emit({"type": "http_request", "method": "GET", "path": parsed.path, "query": parsed.query, "peer": self.client_address[0]})
            if parsed.path in ("/api/localsend/v1/info", "/api/localsend/v2/info"):
                self.json_response(200, state.info())
                return
            self.json_response(404, {"message": "Not found"})

        def do_POST(self):
            parsed = urllib.parse.urlparse(self.path)
            if state.args.debug_http:
                emit({"type": "http_request", "method": "POST", "path": parsed.path, "query": parsed.query, "peer": self.client_address[0], "contentLength": self.headers.get("Content-Length") or "", "transferEncoding": self.headers.get("Transfer-Encoding") or ""})
            if parsed.path in ("/api/localsend/v1/register", "/api/localsend/v2/register"):
                try:
                    payload = self.read_json()
                    emit({"type": "device", "name": payload.get("alias") or self.client_address[0], "alias": payload.get("alias") or self.client_address[0], "ip": self.client_address[0], "port": payload.get("port") or state.args.port, "protocol": payload.get("protocol") or state.args.protocol, "version": payload.get("version") or "1.0", "os": payload.get("deviceType") or "desktop", "fingerprint": payload.get("fingerprint") or ""})
                except Exception:
                    pass
                self.json_response(200, state.info())
                return
            if parsed.path in ("/api/localsend/v1/send-request", "/api/localsend/v2/prepare-upload"):
                try:
                    payload = self.read_json()
                    if not payload.get("files"):
                        self.json_response(400, {"message": "Request must contain at least one file"})
                        return
                    if not state.request_confirmation(self.client_address[0], payload):
                        self.json_response(403, {"message": "Transfer rejected"})
                        return
                    session_id, tokens = state.create_session(self.client_address[0], payload)
                    if parsed.path.startswith("/api/localsend/v1/"):
                        self.json_response(200, tokens)
                    else:
                        self.json_response(200, {"sessionId": session_id, "files": tokens})
                except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, ssl.SSLEOFError):
                    return
                except OSError as exc:
                    if is_disconnected_client_error(exc):
                        return
                    self.json_response(400, {"message": str(exc)})
                except Exception as exc:
                    self.json_response(400, {"message": str(exc)})
                return
            if parsed.path in ("/api/localsend/v1/send", "/api/localsend/v2/upload"):
                self.handle_upload(parsed)
                return
            if parsed.path in ("/api/localsend/v1/cancel", "/api/localsend/v2/cancel"):
                self.json_response(200, {})
                return
            if parsed.path in ("/api/localsend/v1/show", "/api/localsend/v2/show"):
                self.json_response(200, {})
                return
            self.json_response(404, {"message": "Not found"})

        def handle_upload(self, parsed):
            query = urllib.parse.parse_qs(parsed.query)
            file_id = (query.get("fileId") or [""])[0]
            token = (query.get("token") or [""])[0]
            session_id = (query.get("sessionId") or [None])[0]
            resolved_id, session = state.find_session(session_id, file_id, token)
            if not session:
                self.json_response(403, {"message": "Invalid token"})
                return
            dto = session["files"].get(file_id) or {}
            file_name = dto.get("fileName") or file_id
            file_size = int(dto.get("size") or int(self.headers.get("Content-Length") or 0))
            sender = (session.get("sender") or {}).get("alias") or self.client_address[0]
            destination = safe_destination(os.path.abspath(os.path.expanduser(state.args.directory)), file_name)
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            received = 0
            last_emit = 0.0

            def emit_receive_progress(force=False):
                nonlocal last_emit
                finished_value, aggregate_value, total_value = state.mark_received(resolved_id, file_id, received)
                now = time.monotonic()
                if force or now - last_emit > 0.08:
                    last_emit = now
                    emit({
                        "type": "progress",
                        "direction": "receive",
                        "status": "receiving",
                        "peer": sender,
                        "fileName": file_name,
                        "progress": 1.0 if total_value == 0 else min(1.0, aggregate_value / total_value),
                        "fileProgress": 1.0 if file_size == 0 else min(1.0, received / file_size),
                        "sentBytes": aggregate_value,
                        "totalBytes": total_value,
                        "fileBytesSent": received,
                        "fileSize": file_size,
                    })
                return finished_value, aggregate_value, total_value

            with open(destination, "wb") as handle:
                transfer_encoding = (self.headers.get("Transfer-Encoding") or "").lower()
                if "chunked" in transfer_encoding:
                    while True:
                        line = self.rfile.readline()
                        if not line:
                            break
                        size_text = line.split(b";", 1)[0].strip()
                        if not size_text:
                            continue
                        try:
                            chunk_remaining = int(size_text, 16)
                        except ValueError:
                            break
                        if chunk_remaining == 0:
                            while True:
                                trailer = self.rfile.readline()
                                if trailer in (b"\r\n", b"\n", b""):
                                    break
                            break
                        while chunk_remaining > 0:
                            chunk = self.rfile.read(min(CHUNK_SIZE, chunk_remaining))
                            if not chunk:
                                chunk_remaining = 0
                                break
                            handle.write(chunk)
                            received += len(chunk)
                            chunk_remaining -= len(chunk)
                            emit_receive_progress()
                        self.rfile.read(2)
                else:
                    remaining = int(self.headers.get("Content-Length") or file_size or 0)
                    while remaining > 0:
                        chunk = self.rfile.read(min(CHUNK_SIZE, remaining))
                        if not chunk:
                            break
                        handle.write(chunk)
                        received += len(chunk)
                        remaining -= len(chunk)
                        emit_receive_progress(remaining == 0)
            finished, aggregate, total = emit_receive_progress(True)
            emit({"type": "file_finished", "direction": "receive", "status": "receiving", "peer": sender, "fileName": file_name, "path": destination, "progress": 1.0 if total == 0 else min(1.0, aggregate / total), "sentBytes": aggregate, "totalBytes": total})
            if finished:
                emit({"type": "finished", "direction": "receive", "status": "finished", "peer": sender, "path": state.args.directory, "progress": 1, "sentBytes": aggregate, "totalBytes": total})
            self.json_response(200, {})

    return Handler


def multicast_responder(state, stop_event):
    try:
        sock = udp_socket(state.args.group, state.args.port)
    except OSError as exc:
        emit({"type": "warning", "message": f"UDP discovery disabled: {exc}"})
        return
    sock.settimeout(0.5)
    own = state.fingerprint
    interfaces = local_ipv4_addresses()
    while not stop_event.is_set():
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            continue
        except OSError:
            break
        try:
            dto = json.loads(data.decode("utf-8"))
        except Exception:
            continue
        if dto.get("fingerprint") == own:
            continue
        device = parse_device(dto, addr[0], state.args.port)
        emit(device)
        if dto.get("announcement") is True or dto.get("announce") is True:
            answered = False
            try:
                request_json(
                    device.get("protocol") or "https",
                    device["ip"],
                    device.get("port") or state.args.port,
                    device.get("version") or PROTOCOL_VERSION,
                    "register",
                    state.info(),
                    timeout=2,
                )
                answered = True
            except Exception as exc:
                if state.args.debug_http:
                    emit({"type": "warning", "message": f"TCP discovery register failed for {device['ip']}: {exc}"})
            if answered:
                continue
            try:
                send_multicast(state.args.alias, state.args.port, state.args.group, state.args.protocol, False, state.args.port, interfaces, state.fingerprint)
            except OSError:
                pass
    sock.close()


def multicast_announcer(state, stop_event):
    interfaces = local_ipv4_addresses()
    waits = [0.1, 0.5, 2.0]
    index = 0
    while not stop_event.is_set():
        try:
            send_multicast(state.args.alias, state.args.port, state.args.group, state.args.protocol, True, state.args.port, interfaces, state.fingerprint)
        except OSError:
            pass
        wait = waits[index] if index < len(waits) else 5.0
        index += 1
        stop_event.wait(wait)


def receive(args):
    os.makedirs(os.path.abspath(os.path.expanduser(args.directory)), exist_ok=True)
    if args.replace_stale_receiver:
        stale = stop_stale_receivers(args.port)
        if stale:
            emit({"type": "receiver_takeover", "status": "restarting", "port": args.port, "pids": stale})
    state = ReceiveState(args)
    if args.protocol == "https":
        try:
            state.cert_path, state.key_path, state.fingerprint = ensure_tls_material(args.cert, args.key)
        except Exception as exc:
            emit({"type": "error", "status": "error", "message": str(exc)})
            return 1
    stop_event = threading.Event()
    responder_thread = threading.Thread(target=multicast_responder, args=(state, stop_event), daemon=True)
    announcer_thread = threading.Thread(target=multicast_announcer, args=(state, stop_event), daemon=True)
    responder_thread.start()
    announcer_thread.start()
    try:
        server = ThreadingHTTPServer((args.bind, args.port), receive_handler_factory(state))
    except OSError as exc:
        stop_event.set()
        if exc.errno == errno.EADDRINUSE:
            emit({"type": "error", "status": "error", "message": f"LocalSend receive port {args.port} is already in use. Another receiver is already running."})
        else:
            emit({"type": "error", "status": "error", "message": str(exc)})
        return 1
    if args.protocol == "https":
        try:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(certfile=state.cert_path, keyfile=state.key_path)
            server.socket = context.wrap_socket(server.socket, server_side=True)
        except Exception as exc:
            stop_event.set()
            server.server_close()
            emit({"type": "error", "status": "error", "message": str(exc)})
            return 1
    emit({"type": "receiver_started", "status": "listening", "port": args.port, "protocol": args.protocol, "fingerprint": state.fingerprint, "directory": os.path.abspath(os.path.expanduser(args.directory))})
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop_event.set()
        server.shutdown()
        emit({"type": "receiver_stopped"})
    return 0


def confirm_receive(args):
    os.makedirs(CONFIRM_DIR, exist_ok=True)
    payload = {"accepted": bool(args.accept), "time": time.time()}
    tmp_path = confirmation_path(args.id) + ".tmp"
    final_path = confirmation_path(args.id)
    with open(tmp_path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"))
    os.replace(tmp_path, final_path)
    emit({"type": "confirmation_written", "id": args.id, "accepted": payload["accepted"]})
    return 0


def build_parser():
    parser = argparse.ArgumentParser(prog="qs-localsend")
    sub = parser.add_subparsers(dest="command", required=True)

    scan_parser = sub.add_parser("scan")
    scan_parser.add_argument("--timeout", type=float, default=2.5)
    scan_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    scan_parser.add_argument("--group", default=DEFAULT_GROUP)
    scan_parser.add_argument("--alias", default=alias_default())
    scan_parser.add_argument("--protocol", choices=("http", "https"), default="http")
    scan_parser.add_argument("--tcp-register", dest="tcp_register", action="store_true", default=True)
    scan_parser.add_argument("--no-tcp-register", dest="tcp_register", action="store_false")
    scan_parser.add_argument("--probe-subnet", dest="probe_subnet", action="store_true", default=True)
    scan_parser.add_argument("--no-probe-subnet", dest="probe_subnet", action="store_false")
    scan_parser.add_argument("--probe-timeout", type=float, default=0.8)
    scan_parser.add_argument("--probe-workers", type=int, default=64)
    scan_parser.add_argument("--probe-ip", action="append")
    scan_parser.add_argument("--debug", action="store_true")
    scan_parser.set_defaults(func=scan)

    probe_parser = sub.add_parser("probe")
    probe_parser.add_argument("--ip", required=True)
    probe_parser.add_argument("--port", type=int, action="append")
    probe_parser.add_argument("--protocol", choices=("http", "https"), action="append")
    probe_parser.add_argument("--version", action="append")
    probe_parser.add_argument("--timeout", type=float, default=2)
    probe_parser.add_argument("--force-http", action="store_true")
    probe_parser.set_defaults(func=probe)

    send_parser = sub.add_parser("send")
    send_parser.add_argument("--ip", required=True)
    send_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    send_parser.add_argument("--protocol", choices=("auto", "http", "https"), default="auto")
    send_parser.add_argument("--version", default="auto")
    send_parser.add_argument("--name", default="")
    send_parser.add_argument("--alias", default=alias_default())
    send_parser.add_argument("--own-port", type=int, default=DEFAULT_PORT)
    send_parser.add_argument("--own-protocol", choices=("http", "https"), default="https")
    send_parser.add_argument("--cert", default=TLS_CERT_PATH)
    send_parser.add_argument("--key", default=TLS_KEY_PATH)
    send_parser.add_argument("--pin", default="")
    send_parser.add_argument("--prepare-timeout", type=float, default=300)
    send_parser.add_argument("--upload-timeout", type=float, default=300)
    send_parser.add_argument("--file", action="append", default=[])
    send_parser.add_argument("files", nargs="*")
    send_parser.set_defaults(func=send)

    pick_parser = sub.add_parser("pick-files")
    pick_parser.set_defaults(func=pick_files)

    receive_parser = sub.add_parser("receive")
    receive_parser.add_argument("--directory", default=os.path.expanduser("~/Downloads/LocalSend"))
    receive_parser.add_argument("--bind", default="")
    receive_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    receive_parser.add_argument("--group", default=DEFAULT_GROUP)
    receive_parser.add_argument("--alias", default=alias_default())
    receive_parser.add_argument("--protocol", choices=("http", "https"), default="https")
    receive_parser.add_argument("--cert", default=TLS_CERT_PATH)
    receive_parser.add_argument("--key", default=TLS_KEY_PATH)
    receive_parser.add_argument("--auto-accept-ip", action="append", default=list(DEFAULT_AUTO_ACCEPT_IPS))
    receive_parser.add_argument("--confirm-timeout", type=float, default=120)
    receive_parser.add_argument("--debug-http", action="store_true")
    receive_parser.add_argument("--replace-stale-receiver", action="store_true")
    receive_parser.set_defaults(func=receive)

    confirm_parser = sub.add_parser("confirm-receive")
    confirm_parser.add_argument("--id", required=True)
    confirm_group = confirm_parser.add_mutually_exclusive_group(required=True)
    confirm_group.add_argument("--accept", action="store_true")
    confirm_group.add_argument("--reject", action="store_true")
    confirm_parser.set_defaults(func=confirm_receive)

    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args) or 0
    except Exception as exc:
        emit({"type": "error", "message": str(exc)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
