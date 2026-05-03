#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import time

CACHE_DIR = os.path.join(os.path.expanduser("~"), ".cache", "quickshell", "vicinae-clipboard")
MAX_TEXT_PREVIEW = 5000


def emit(payload):
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def human_size(size):
    value = float(size)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024 or unit == "GB":
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.2f} {unit}"
        value /= 1024
    return f"{size} B"


def token_for_raw(raw):
    return base64.urlsafe_b64encode(raw.encode("utf-8")).decode("ascii")


def raw_for_token(token):
    return base64.urlsafe_b64decode(token.encode("ascii")).decode("utf-8")


def parse_binary_preview(preview):
    match = re.match(r"^\[\[\s*binary data\s+(.+?)\s+([A-Za-z0-9.+_-]+)\s+(\d+x\d+)\s*\]\]$", preview.strip())
    if not match:
        return None

    size_text = match.group(1).strip()
    format_name = match.group(2).strip().lower()
    dimensions = match.group(3).strip()
    mime = "image/jpeg" if format_name in ("jpg", "jpeg") else f"image/{format_name}"

    return {
        "sizeText": size_text,
        "formatName": format_name,
        "dimensions": dimensions,
        "mime": mime,
    }


def build_item(index, raw):
    item_id, preview = raw.split("\t", 1) if "\t" in raw else (str(index), raw)
    binary = parse_binary_preview(preview)
    is_image = bool(binary and binary["mime"].startswith("image/"))
    compact = re.sub(r"\s+", " ", preview).strip()

    if is_image:
        title = f"Image ({binary['dimensions']})"
        subtitle = f"Clipboard item #{item_id}"
        icon_text = "󰋩"
        mime = binary["mime"]
        size_text = binary["sizeText"]
        preview_text = compact
        dimensions = binary["dimensions"]
    else:
        title = compact[:90] if compact else "Text"
        subtitle = f"Clipboard item #{item_id}"
        icon_text = "T"
        mime = "text/plain"
        size_text = ""
        preview_text = preview
        dimensions = ""

    return {
        "index": index,
        "itemId": item_id,
        "rawToken": token_for_raw(raw),
        "title": title,
        "subtitle": subtitle,
        "previewText": preview_text,
        "iconText": icon_text,
        "isImage": is_image,
        "imagePath": "",
        "mime": mime,
        "sizeText": size_text,
        "dimensions": dimensions,
        "md5": "",
        "copiedAt": subtitle,
    }


def cliphist_list():
    return subprocess.run(["cliphist", "list"], text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def decode_raw(raw):
    return subprocess.run(["cliphist", "decode"], input=(raw + "\n").encode("utf-8"), stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def command_list(argv):
    query = argv[0].casefold().strip() if argv else ""
    limit = int(argv[1]) if len(argv) > 1 and argv[1].isdigit() else 750
    result = cliphist_list()

    if result.returncode != 0:
        emit({"error": "Failed to load clipboard history"})
        return result.returncode

    count = 0
    for index, raw in enumerate(result.stdout.splitlines()):
        if not raw:
            continue

        item = build_item(index, raw)
        haystack = " ".join((item["title"], item["subtitle"], item["previewText"], item["mime"], item["itemId"])).casefold()

        if query and query not in haystack:
            continue

        emit(item)
        count += 1

        if count >= limit:
            break

    return 0


def extension_for_mime(mime):
    return {
        "image/png": "png",
        "image/jpeg": "jpg",
        "image/gif": "gif",
        "image/webp": "webp",
        "image/bmp": "bmp",
    }.get(mime, "bin")


def text_from_bytes(data):
    for encoding in ("utf-8", "utf-16", "latin-1"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    return ""


def command_preview(argv):
    if not argv:
        emit({"error": "Missing clipboard item"})
        return 2

    token = argv[0]
    raw = raw_for_token(token)
    item = build_item(0, raw)
    decoded = decode_raw(raw)

    if decoded.returncode != 0:
        emit({"rawToken": token, "error": "Failed to decode clipboard item"})
        return decoded.returncode

    data = decoded.stdout
    digest = hashlib.md5(data).hexdigest()
    payload = {
        "rawToken": token,
        "mime": item["mime"],
        "sizeText": human_size(len(data)),
        "md5": digest,
        "previewText": item["previewText"],
        "imagePath": "",
    }

    if item["isImage"]:
        os.makedirs(CACHE_DIR, exist_ok=True)
        path = os.path.join(CACHE_DIR, f"{digest}.{extension_for_mime(item['mime'])}")
        if not os.path.exists(path):
            with open(path, "wb") as handle:
                handle.write(data)
        payload["imagePath"] = path
    else:
        payload["previewText"] = text_from_bytes(data)[:MAX_TEXT_PREVIEW]

    emit(payload)
    return 0


def write_clipboard(token):
    raw = raw_for_token(token)
    item = build_item(0, raw)
    decoded = decode_raw(raw)

    if decoded.returncode != 0:
        return decoded.returncode

    copied = subprocess.run(["wl-copy", "--type", item["mime"]], input=decoded.stdout)
    return copied.returncode


def command_copy(argv):
    if not argv:
        return 2
    return write_clipboard(argv[0])


def command_paste(argv):
    if not argv:
        return 2

    copied = write_clipboard(argv[0])
    if copied != 0:
        return copied

    time.sleep(0.38)
    pasted = subprocess.run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"])
    return pasted.returncode


def main():
    if len(sys.argv) < 2:
        return 2

    command = sys.argv[1]
    argv = sys.argv[2:]

    if command == "list":
        return command_list(argv)
    if command == "preview":
        return command_preview(argv)
    if command == "copy":
        return command_copy(argv)
    if command == "paste":
        return command_paste(argv)

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
