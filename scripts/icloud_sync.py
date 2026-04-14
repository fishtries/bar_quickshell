#!/usr/bin/env python3
import caldav
import json
import os
import sys
from datetime import datetime
from tempfile import NamedTemporaryFile

# === CONFIGURATION ===
# Replace with your iCloud Email and App-Specific Password
USERNAME = "fishfishlovesfish@icloud.com"
PASSWORD = "jyfv-jlsd-qzhx-xway"
URL = "https://caldav.icloud.com/"
DATA_FILE = os.path.expanduser("~/.config/quickshell/data/events.json")
# =====================

def fetch_reminders():
    try:
        client = caldav.DAVClient(url=URL, username=USERNAME, password=PASSWORD)
        principal = client.principal()
        calendars = principal.calendars()
        
        events_by_date = {}

        for calendar in calendars:
            # Attempt to fetch only uncompleted todos
            # Apple lists are calendars that support VTODO
            try:
                todos = calendar.get_todos(include_completed=False)
            except Exception:
                # Some "calendars" might not support todos, skip them
                continue

            for todo in todos:
                ical = todo.icalendar_component
                
                # Check summary (title)
                summary = str(ical.get('summary', ''))
                if not summary:
                    continue

                # Check status - double check it's not completed
                status = str(ical.get('status', 'NEEDS-ACTION')).upper()
                if status == 'COMPLETED':
                    continue

                # Check deadline (DUE)
                due = ical.get('due')
                if not due:
                    continue
                
                dt = due.dt
                # dt can be a datetime.date (all-day) or datetime.datetime (with time)
                if isinstance(dt, datetime):
                    date_key = dt.strftime('%Y-%m-%d')
                    time_val = dt.strftime('%H:%M')
                else:
                    date_key = dt.strftime('%Y-%m-%d')
                    time_val = None

                # Initialize date group if not exists
                if date_key not in events_by_date:
                    events_by_date[date_key] = []

                events_by_date[date_key].append({
                    "title": summary,
                    "list": calendar.name,
                    "time": time_val
                })

        # Sort tasks within each date by time
        for date_key in events_by_date:
            events_by_date[date_key].sort(key=lambda x: x['time'] if x['time'] else '23:59')

        return events_by_date

    except Exception as e:
        print(f"Error fetching reminders: {e}", file=sys.stderr)
        return None

def save_json(data):
    if data is None:
        return

    # Ensure parent directory exists
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)

    # Atomic write using a temporary file
    temp_dir = os.path.dirname(DATA_FILE)
    with NamedTemporaryFile('w', dir=temp_dir, delete=False, suffix='.json') as tf:
        json.dump(data, tf, indent=2, ensure_ascii=False)
        temp_path = tf.name

    try:
        os.chmod(temp_path, 0o644)
        os.replace(temp_path, DATA_FILE)
    except Exception as e:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        print(f"Error saving JSON: {e}", file=sys.stderr)

if __name__ == "__main__":
    reminders = fetch_reminders()
    if reminders is not None:
        save_json(reminders)
