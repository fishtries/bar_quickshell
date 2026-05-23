from __future__ import annotations

import json
import os
from datetime import datetime, timedelta
from pathlib import Path

TOOL_SPEC = {
    "name": "reminders",
    "description": (
        "Create, search, list, and update the user's desktop reminders stored in "
        "Quickshell events.json. Use this when the user asks to set a reminder, "
        "move/reschedule a reminder, rename a reminder, or change its list. Dates "
        "should be explicit YYYY-MM-DD and times should be HH:MM in 24-hour local "
        "time. If the requested date or time is ambiguous, ask a clarifying question "
        "before creating or updating a reminder. For updates, first use search/list "
        "if the target reminder is not uniquely identified."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["create", "update", "list", "search"],
                "description": "create a reminder, update one existing reminder, list reminders, or search reminders.",
            },
            "title": {
                "type": "string",
                "description": "For create: reminder text/title.",
            },
            "date": {
                "type": "string",
                "description": "For create/list/search: target date as YYYY-MM-DD. Optional for list/search.",
            },
            "time": {
                "type": "string",
                "description": "For create: reminder time as HH:MM in 24-hour local time.",
            },
            "list_name": {
                "type": "string",
                "description": "Reminder list name. Defaults to Reminders.",
            },
            "query": {
                "type": "string",
                "description": "For search/list/update: case-insensitive text to match in the title or list name.",
            },
            "count": {
                "type": "integer",
                "description": "For list/search: maximum number of reminders to return. Default is 20.",
            },
            "old_date": {
                "type": "string",
                "description": "For update: current date of the reminder as YYYY-MM-DD.",
            },
            "old_index": {
                "type": "integer",
                "description": "For update: zero-based index within old_date, as returned by list/search.",
            },
            "old_title": {
                "type": "string",
                "description": "For update: current title or a distinctive part of it.",
            },
            "old_time": {
                "type": "string",
                "description": "For update: current time as HH:MM.",
            },
            "old_list_name": {
                "type": "string",
                "description": "For update: current list name.",
            },
            "new_title": {
                "type": "string",
                "description": "For update: replacement title. Omit to keep the current title.",
            },
            "new_date": {
                "type": "string",
                "description": "For update: replacement date as YYYY-MM-DD. Omit to keep the current date.",
            },
            "new_time": {
                "type": "string",
                "description": "For update: replacement time as HH:MM. Omit to keep the current time.",
            },
            "new_list_name": {
                "type": "string",
                "description": "For update: replacement list name. Omit to keep the current list.",
            },
        },
        "required": ["action"],
    },
}

_DEFAULT_EVENTS_FILE = Path.home() / ".config" / "quickshell" / "data" / "events.json"


def _events_file() -> Path:
    return Path(os.environ.get("ASIDE_EVENTS_FILE", str(_DEFAULT_EVENTS_FILE))).expanduser()


def _load_events(path: Path) -> dict:
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return {}
    data = json.loads(text)
    return data if isinstance(data, dict) else {}


def _save_events(path: Path, data: dict) -> None:
    cleaned = {}
    for date_key in sorted(data):
        tasks = data.get(date_key)
        if not isinstance(tasks, list):
            continue
        valid_tasks = [task for task in tasks if isinstance(task, dict) and (task.get("title") or "").strip()]
        if not valid_tasks:
            continue
        valid_tasks.sort(key=lambda task: (task.get("time") or "99:99", task.get("title") or ""))
        cleaned[date_key] = valid_tasks
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(cleaned, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(path)


def _normalize_date(value: str | None, *, required: bool = False) -> str | None:
    if value is None:
        if required:
            raise ValueError("date is required")
        return None
    text = str(value).strip().lower()
    if not text:
        if required:
            raise ValueError("date is required")
        return None
    today = datetime.now().date()
    if text in {"today", "сегодня"}:
        return today.isoformat()
    if text in {"tomorrow", "завтра"}:
        return (today + timedelta(days=1)).isoformat()
    if text in {"day after tomorrow", "послезавтра"}:
        return (today + timedelta(days=2)).isoformat()
    for fmt in ("%Y-%m-%d", "%d.%m.%Y", "%d/%m/%Y"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            pass
    raise ValueError(f"invalid date '{value}', expected YYYY-MM-DD")


def _normalize_time(value: str | None, *, required: bool = False) -> str | None:
    if value is None:
        if required:
            raise ValueError("time is required")
        return None
    text = str(value).strip().replace(".", ":")
    if not text:
        if required:
            raise ValueError("time is required")
        return ""
    if text.isdigit() and 0 <= int(text) <= 23:
        text = f"{int(text):02d}:00"
    elif ":" in text:
        hour_text, minute_text, *rest = text.split(":")
        if rest:
            raise ValueError(f"invalid time '{value}', expected HH:MM")
        if not hour_text.isdigit() or not minute_text.isdigit():
            raise ValueError(f"invalid time '{value}', expected HH:MM")
        text = f"{int(hour_text):02d}:{int(minute_text):02d}"
    else:
        raise ValueError(f"invalid time '{value}', expected HH:MM")
    datetime.strptime(text, "%H:%M")
    return text


def _clean_title(value: str | None, *, required: bool = False) -> str | None:
    if value is None:
        if required:
            raise ValueError("title is required")
        return None
    text = str(value).strip()
    if not text and required:
        raise ValueError("title is required")
    return text


def _clean_list_name(value: str | None, *, default: str | None = None) -> str | None:
    if value is None:
        return default
    return str(value).strip()


def _task_line(date_key: str, index: int, task: dict) -> str:
    time_value = task.get("time") or "--:--"
    list_name = task.get("list") or ""
    suffix = f" [{list_name}]" if list_name else ""
    return f"{date_key} #{index} {time_value} — {task.get('title') or 'Reminder'}{suffix}"


def _matches_text(task: dict, query: str | None) -> bool:
    if not query:
        return True
    needle = query.casefold()
    return needle in str(task.get("title") or "").casefold() or needle in str(task.get("list") or "").casefold()


def _matches_field(actual: str, expected: str | None, *, partial: bool = False) -> bool:
    if expected is None or str(expected).strip() == "":
        return True
    actual_text = str(actual or "").casefold()
    expected_text = str(expected).strip().casefold()
    if partial:
        return expected_text in actual_text
    return actual_text == expected_text


def _iter_reminders(data: dict, date_key: str | None = None):
    for current_date in sorted(data):
        if date_key and current_date != date_key:
            continue
        tasks = data.get(current_date)
        if not isinstance(tasks, list):
            continue
        for index, task in enumerate(tasks):
            if isinstance(task, dict):
                yield current_date, index, task


def _format_results(matches: list[tuple[str, int, dict]], heading: str) -> str:
    if not matches:
        return "No reminders found."
    lines = [heading, ""]
    lines.extend(_task_line(date_key, index, task) for date_key, index, task in matches)
    return "\n".join(lines)


def _create(data: dict, title: str, date_key: str, time_value: str, list_name: str) -> str:
    tasks = data.setdefault(date_key, [])
    for task in tasks:
        if not isinstance(task, dict):
            continue
        if (task.get("title") or "") == title and (task.get("time") or "") == time_value and (task.get("list") or "") == list_name:
            return f"Reminder already exists: {_task_line(date_key, tasks.index(task), task)}"
    tasks.append({"title": title, "list": list_name, "time": time_value})
    return f"Created reminder: {date_key} {time_value} — {title} [{list_name}]"


def _find_update_matches(
    data: dict,
    old_date: str | None,
    old_index: int | str | None,
    old_title: str | None,
    old_time: str | None,
    old_list_name: str | None,
    query: str | None,
) -> list[tuple[str, int, dict]]:
    if old_date and old_index is not None:
        try:
            index = int(old_index)
        except (TypeError, ValueError):
            return []
        tasks = data.get(old_date)
        if isinstance(tasks, list) and 0 <= index < len(tasks) and isinstance(tasks[index], dict):
            task = tasks[index]
            if (
                _matches_field(task.get("title") or "", old_title, partial=True)
                and _matches_field(task.get("time") or "", old_time)
                and _matches_field(task.get("list") or "", old_list_name)
                and _matches_text(task, query)
            ):
                return [(old_date, index, task)]
        return []

    if not any([old_date, old_title, old_time, old_list_name, query]):
        raise ValueError("update needs old_date + old_index, or old_title/query/old_time details to identify one reminder")

    matches = []
    for date_key, index, task in _iter_reminders(data, old_date):
        if not _matches_field(task.get("title") or "", old_title, partial=True):
            continue
        if not _matches_field(task.get("time") or "", old_time):
            continue
        if not _matches_field(task.get("list") or "", old_list_name):
            continue
        if not _matches_text(task, query):
            continue
        matches.append((date_key, index, task))
    return matches


def _update(
    data: dict,
    old_date: str | None,
    old_index: int | str | None,
    old_title: str | None,
    old_time: str | None,
    old_list_name: str | None,
    query: str | None,
    new_title: str | None,
    new_date: str | None,
    new_time: str | None,
    new_list_name: str | None,
) -> str:
    if new_title is None and new_date is None and new_time is None and new_list_name is None:
        raise ValueError("update needs at least one new_* field")

    matches = _find_update_matches(data, old_date, old_index, old_title, old_time, old_list_name, query)
    if not matches:
        return "No matching reminder found; update was not applied."
    if len(matches) > 1:
        return _format_results(matches[:20], f"Found {len(matches)} matching reminders; update was not applied. Specify old_date and old_index.")

    source_date, index, task = matches[0]
    tasks = data.get(source_date)
    if not isinstance(tasks, list):
        return "No matching reminder found; update was not applied."

    current = dict(task)
    updated = dict(task)
    target_date = new_date or source_date
    if new_title is not None:
        updated["title"] = new_title
    if new_time is not None:
        updated["time"] = new_time
    if new_list_name is not None:
        updated["list"] = new_list_name

    tasks.pop(index)
    if not tasks:
        data.pop(source_date, None)
    data.setdefault(target_date, []).append(updated)

    return f"Updated reminder: {_task_line(source_date, index, current)} -> {_task_line(target_date, 0, updated)}"


def run(
    action: str,
    title: str | None = None,
    date: str | None = None,
    time: str | None = None,
    list_name: str | None = None,
    query: str | None = None,
    count: int | str | None = 20,
    old_date: str | None = None,
    old_index: int | str | None = None,
    old_title: str | None = None,
    old_time: str | None = None,
    old_list_name: str | None = None,
    new_title: str | None = None,
    new_date: str | None = None,
    new_time: str | None = None,
    new_list_name: str | None = None,
) -> str:
    try:
        current_action = str(action or "").strip().lower()
        if current_action in {"set", "add"}:
            current_action = "create"
        if current_action in {"edit", "change", "move", "reschedule"}:
            current_action = "update"

        path = _events_file()
        data = _load_events(path)

        if current_action == "create":
            clean_title = _clean_title(title, required=True)
            date_key = _normalize_date(date, required=True)
            time_value = _normalize_time(time, required=True)
            clean_list = _clean_list_name(list_name, default="Reminders") or "Reminders"
            message = _create(data, clean_title, date_key, time_value, clean_list)
            _save_events(path, data)
            return message

        if current_action in {"list", "search"}:
            date_key = _normalize_date(date) if date is not None else None
            try:
                limit = max(1, min(int(count or 20), 100))
            except (TypeError, ValueError):
                limit = 20
            matches = [item for item in _iter_reminders(data, date_key) if _matches_text(item[2], query)]
            if current_action == "search" and not query:
                return "Error: query is required for search."
            return _format_results(matches[:limit], f"Found {len(matches)} reminder(s):")

        if current_action == "update":
            normalized_old_date = _normalize_date(old_date) if old_date is not None else None
            normalized_old_time = _normalize_time(old_time) if old_time is not None else None
            normalized_new_date = _normalize_date(new_date) if new_date is not None else None
            normalized_new_time = _normalize_time(new_time) if new_time is not None else None
            clean_old_title = _clean_title(old_title)
            clean_old_list = _clean_list_name(old_list_name)
            clean_new_title = _clean_title(new_title) if new_title is not None else None
            clean_new_list = _clean_list_name(new_list_name) if new_list_name is not None else None
            message = _update(
                data,
                normalized_old_date,
                old_index,
                clean_old_title,
                normalized_old_time,
                clean_old_list,
                query.strip() if query else None,
                clean_new_title,
                normalized_new_date,
                normalized_new_time,
                clean_new_list,
            )
            if message.startswith("Updated reminder:"):
                _save_events(path, data)
            return message

        return f"Unknown action: {action}"
    except (json.JSONDecodeError, OSError, ValueError) as exc:
        return f"Error: {exc}"
