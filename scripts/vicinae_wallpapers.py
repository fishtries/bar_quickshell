#!/usr/bin/env python3
from __future__ import annotations

import json
import hashlib
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import List, Optional


WALLPAPER_DIR = Path.home() / "wallpapers"
CACHE_DIR = Path.home() / ".cache" / "quickshell" / "vicinae_wallpapers"
THEME_STATE_FILE = CACHE_DIR / "theme.json"
THEME_LIGHT_THRESHOLD = 0.56
THEME_MAP_COLUMNS = 32
THEME_MAP_ROWS = 18
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff", ".avif"}
VIDEO_EXTENSIONS = {".mp4", ".mkv", ".webm", ".mov", ".m4v", ".avi"}
SUPPORTED_EXTENSIONS = IMAGE_EXTENSIONS | VIDEO_EXTENSIONS


def emit(payload: dict) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def readable_size(size: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}" if unit != "B" else f"{int(value)} {unit}"
        value /= 1024
    return f"{size} B"


def video_thumbnail_path(path: Path) -> str:
    try:
        stat = path.stat()
        key = f"{path}:{stat.st_mtime_ns}:{stat.st_size}".encode("utf-8")
    except OSError:
        key = str(path).encode("utf-8")

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = CACHE_DIR / (hashlib.sha256(key).hexdigest() + ".jpg")

    if target.exists() and target.stat().st_size > 0:
        return str(target)

    ffmpegthumbnailer = shutil.which("ffmpegthumbnailer")
    if ffmpegthumbnailer:
        result = subprocess.run(
            [ffmpegthumbnailer, "-i", str(path), "-o", str(target), "-s", "640", "-q", "8"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0 and target.exists() and target.stat().st_size > 0:
            return str(target)

    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        result = subprocess.run(
            [
                ffmpeg,
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-ss",
                "00:00:01",
                "-i",
                str(path),
                "-frames:v",
                "1",
                "-vf",
                "scale=640:-1",
                str(target),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0 and target.exists() and target.stat().st_size > 0:
            return str(target)

    return ""


def luminance_from_rgb_bytes(data: bytes) -> Optional[float]:
    if not data:
        return None

    total = 0.0
    count = 0
    usable_length = len(data) - (len(data) % 3)

    for offset in range(0, usable_length, 3):
        r = data[offset]
        g = data[offset + 1]
        b = data[offset + 2]
        total += 0.2126 * r + 0.7152 * g + 0.0722 * b
        count += 1

    if count == 0:
        return None

    return total / (count * 255.0)


def luminance_profile_from_rgb_bytes(data: bytes, width: int, height: int, columns: int) -> List[float]:
    if not data or width <= 0 or height <= 0 or columns <= 0:
        return []

    totals = [0.0 for _ in range(columns)]
    counts = [0 for _ in range(columns)]
    usable_length = min(len(data), width * height * 3)

    for pixel_index in range(usable_length // 3):
        x = pixel_index % width
        bucket = min(columns - 1, int(x * columns / width))
        offset = pixel_index * 3
        r = data[offset]
        g = data[offset + 1]
        b = data[offset + 2]
        totals[bucket] += 0.2126 * r + 0.7152 * g + 0.0722 * b
        counts[bucket] += 1

    profile = []
    for index in range(columns):
        if counts[index] == 0:
            profile.append(0.0)
        else:
            profile.append(totals[index] / (counts[index] * 255.0))

    return profile


def luminance_profile_with_pillow(path: Path) -> List[float]:
    try:
        from PIL import Image
    except Exception:
        return []

    try:
        with Image.open(path) as image:
            try:
                image.seek(0)
            except EOFError:
                pass

            resampling = getattr(getattr(Image, "Resampling", Image), "BILINEAR")
            rgb_image = image.convert("RGB").resize((THEME_MAP_COLUMNS, THEME_MAP_ROWS), resampling)
            return luminance_profile_from_rgb_bytes(rgb_image.tobytes(), THEME_MAP_COLUMNS, THEME_MAP_ROWS, THEME_MAP_COLUMNS)
    except Exception:
        return []


def luminance_with_pillow(path: Path) -> Optional[float]:
    try:
        from PIL import Image
    except Exception:
        return None

    try:
        with Image.open(path) as image:
            try:
                image.seek(0)
            except EOFError:
                pass

            image.thumbnail((96, 96))
            rgb_image = image.convert("RGB")
            return luminance_from_rgb_bytes(rgb_image.tobytes())
    except Exception:
        return None


def luminance_with_ffmpeg(path: Path) -> Optional[float]:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return None

    try:
        command = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
        ]

        if path.suffix.lower() in VIDEO_EXTENSIONS:
            command.extend(["-ss", "00:00:01"])

        command.extend(
            [
                "-i",
                str(path),
                "-frames:v",
                "1",
                "-vf",
                "scale=64:64:force_original_aspect_ratio=decrease",
                "-f",
                "rawvideo",
                "-pix_fmt",
                "rgb24",
                "-",
            ]
        )

        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=6,
        )
    except Exception:
        return None

    if result.returncode != 0:
        return None

    return luminance_from_rgb_bytes(result.stdout)


def luminance_profile_with_ffmpeg(path: Path) -> List[float]:
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        return []

    try:
        command = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
        ]

        if path.suffix.lower() in VIDEO_EXTENSIONS:
            command.extend(["-ss", "00:00:01"])

        command.extend(
            [
                "-i",
                str(path),
                "-frames:v",
                "1",
                "-vf",
                f"scale={THEME_MAP_COLUMNS}:{THEME_MAP_ROWS}",
                "-f",
                "rawvideo",
                "-pix_fmt",
                "rgb24",
                "-",
            ]
        )

        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=6,
        )
    except Exception:
        return []

    if result.returncode != 0:
        return []

    return luminance_profile_from_rgb_bytes(result.stdout, THEME_MAP_COLUMNS, THEME_MAP_ROWS, THEME_MAP_COLUMNS)


def wallpaper_luminance(path: Path) -> Optional[float]:
    luminance = luminance_with_pillow(path)
    if luminance is not None:
        return luminance

    return luminance_with_ffmpeg(path)


def wallpaper_luminance_profile(path: Path) -> List[float]:
    profile = luminance_profile_with_pillow(path)
    if profile:
        return profile

    return luminance_profile_with_ffmpeg(path)


def wallpaper_theme_payload(path: Optional[Path], luminance: Optional[float] = None) -> dict:
    samples = []
    if path is not None and luminance is None:
        samples = wallpaper_luminance_profile(path)
        luminance = sum(samples) / len(samples) if samples else wallpaper_luminance(path)
    elif path is not None:
        samples = wallpaper_luminance_profile(path)

    mode = "light" if luminance is not None and luminance >= THEME_LIGHT_THRESHOLD else "dark"
    return {
        "mode": mode,
        "luminance": round(luminance, 4) if luminance is not None else -1,
        "samples": [round(value, 4) for value in samples],
        "wallpaper": str(path) if path is not None else "",
        "updatedAt": int(time.time()),
    }


def save_wallpaper_theme(path: Path) -> dict:
    payload = wallpaper_theme_payload(path)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    THEME_STATE_FILE.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    return payload


def read_wallpaper_theme() -> int:
    try:
        payload = json.loads(THEME_STATE_FILE.read_text(encoding="utf-8"))
        mode = payload.get("mode")
        samples = payload.get("samples")

        if mode not in {"dark", "light"}:
            payload = wallpaper_theme_payload(None)
        elif not isinstance(samples, list) or len(samples) == 0:
            wallpaper = payload.get("wallpaper", "")
            wallpaper_path = Path(wallpaper) if wallpaper else None
            if wallpaper_path is not None and wallpaper_path.exists():
                payload = wallpaper_theme_payload(wallpaper_path)
    except Exception:
        payload = wallpaper_theme_payload(None)

    emit(payload)
    return 0


def item_for_path(path: Path) -> dict:
    relative = path.relative_to(WALLPAPER_DIR)
    suffix = path.suffix.lower()
    is_video = suffix in VIDEO_EXTENSIONS
    size_text = ""

    try:
        size_text = readable_size(path.stat().st_size)
    except OSError:
        pass

    return {
        "section": "Wallpapers",
        "kind": "result",
        "title": path.stem.replace("_", " ").replace("-", " "),
        "subtitle": f"{'Video' if is_video else 'Image'} • ~/{Path('wallpapers') / relative}" + (f" • {size_text}" if size_text else ""),
        "iconText": "󰨜" if is_video else "󰋩",
        "isVideo": is_video,
        "previewPath": video_thumbnail_path(path) if is_video else str(path),
        "accessoryText": "Set",
        "accessoryColor": "#b8a1ff",
        "aliasText": "wall",
        "keywords": [
            path.name,
            path.stem,
            str(relative),
            str(path),
            "wallpaper",
            "wallpapers",
            "background",
            "mpvpaper",
            "обои",
            "фон",
        ],
        "actionLabel": "Set Wallpaper",
        "launchType": "wallpaper",
        "launchValue": str(path),
        "launchKey": "wallpaper:" + str(path),
    }


def list_wallpapers() -> int:
    if not WALLPAPER_DIR.exists():
        emit({"error": "~/wallpapers does not exist"})
        return 0

    if not WALLPAPER_DIR.is_dir():
        emit({"error": "~/wallpapers is not a directory"})
        return 0

    paths = []
    for path in WALLPAPER_DIR.rglob("*"):
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
            paths.append(path)

    for path in sorted(paths, key=lambda item: str(item.relative_to(WALLPAPER_DIR)).lower()):
        emit(item_for_path(path))

    return 0


def stop_existing_mpvpaper() -> None:
    pkill = shutil.which("pkill")
    if pkill is None:
        return

    subprocess.run([pkill, "-x", "mpvpaper"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.08)


def apply_wallpaper(raw_path: str) -> int:
    mpvpaper = shutil.which("mpvpaper")
    if mpvpaper is None:
        print("mpvpaper is not installed", file=sys.stderr)
        return 1

    path = Path(raw_path).expanduser().resolve()
    try:
        path.relative_to(WALLPAPER_DIR.resolve())
    except ValueError:
        print("wallpaper must be inside ~/wallpapers", file=sys.stderr)
        return 1

    if not path.is_file() or path.suffix.lower() not in SUPPORTED_EXTENSIONS:
        print("unsupported wallpaper file", file=sys.stderr)
        return 1

    stop_existing_mpvpaper()
    subprocess.Popen(
        [mpvpaper, "-o", "no-audio --loop-file=inf --panscan=1.0", "*", str(path)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        close_fds=True,
    )
    emit(save_wallpaper_theme(path))
    return 0


def main() -> int:
    command = sys.argv[1] if len(sys.argv) > 1 else "list"

    if command == "list":
        return list_wallpapers()
    if command == "apply":
        raw_path = sys.argv[2] if len(sys.argv) > 2 else ""
        return apply_wallpaper(raw_path)
    if command == "theme":
        return read_wallpaper_theme()

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
