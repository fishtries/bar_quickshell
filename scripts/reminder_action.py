#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def load_events(path: Path):
    if not path.exists():
        return {}

    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return {}

    data = json.loads(text)
    return data if isinstance(data, dict) else {}


def save_events(path: Path, data):
    for key, tasks in list(data.items()):
        if not isinstance(tasks, list) or len(tasks) == 0:
            data.pop(key, None)
            continue

        tasks.sort(key=lambda task: (task.get("time") or "99:99", task.get("title") or ""))

    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def task_matches(task, title, time_value, list_name):
    if not isinstance(task, dict):
        return False

    return (
        (task.get("title") or "") == title and
        (task.get("time") or "") == time_value and
        (task.get("list") or "") == list_name
    )


def locate_task(tasks, index_hint, title, time_value, list_name):
    if 0 <= index_hint < len(tasks) and task_matches(tasks[index_hint], title, time_value, list_name):
        return index_hint

    for index, task in enumerate(tasks):
        if task_matches(task, title, time_value, list_name):
            return index

    return -1


def pop_task(data, date_key, index_hint, title, time_value, list_name):
    tasks = data.get(date_key)
    if not isinstance(tasks, list):
        return None

    index = locate_task(tasks, index_hint, title, time_value, list_name)
    if index < 0:
        return None

    task = tasks.pop(index)
    if len(tasks) == 0:
        data.pop(date_key, None)

    return task


def main():
    if len(sys.argv) < 8:
        raise SystemExit(1)

    action = sys.argv[1]
    file_path = Path(sys.argv[2]).expanduser()
    date_key = sys.argv[3]
    index_hint = int(sys.argv[4])
    title = sys.argv[5]
    time_value = sys.argv[6]
    list_name = sys.argv[7]

    data = load_events(file_path)
    task = pop_task(data, date_key, index_hint, title, time_value, list_name)
    if task is None:
        raise SystemExit(1)

    if action == "move":
        if len(sys.argv) < 10:
            raise SystemExit(1)

        target_date_key = sys.argv[8]
        target_time = sys.argv[9]
        task["time"] = target_time
        if title:
            task["title"] = title
        if list_name:
            task["list"] = list_name
        data.setdefault(target_date_key, []).append(task)
    elif action == "edit":
        if len(sys.argv) < 12:
            raise SystemExit(1)

        target_date_key = sys.argv[8]
        target_time = sys.argv[9]
        new_title = sys.argv[10].strip()
        new_list_name = sys.argv[11].strip()

        if not new_title:
            raise SystemExit(1)

        task["title"] = new_title
        task["time"] = target_time
        task["list"] = new_list_name
        data.setdefault(target_date_key, []).append(task)
    elif action != "complete":
        raise SystemExit(1)

    save_events(file_path, data)


if __name__ == "__main__":
    main()
