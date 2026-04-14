#!/usr/bin/env python3
import json
import os
import tempfile
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

# Configuration
HOST = '0.0.0.0'
PORT = 8080
DATA_FILE = '/home/fish/.config/quickshell/data/events.json'

class WebhookHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/sync':
            self.send_response(404)
            self.end_headers()
            return

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8')

        try:
            tasks = self.parse_incoming_data(post_data)
            status = self.process_and_save(tasks)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            response = {"status": "success", "message": status}
            self.wfile.write(json.dumps(response).encode('utf-8'))
            print(f"[{datetime.now().isoformat()}] Sync successful: {status}")
            
        except Exception as e:
            self.send_response(500)
            self.end_headers()
            error_msg = f"Error processing request: {str(e)}"
            self.wfile.write(error_msg.encode('utf-8'))
            print(f"[{datetime.now().isoformat()}] {error_msg}")

    def parse_incoming_data(self, data):
        """
        Handle various JSON formats received from iOS Shortcuts:
        1. Proper JSON array: [...]
        2. Proper single JSON object: {...}
        3. New-line delimited JSON (NDJSON): {...}\n{...}
        4. Concatenated JSON: {...}{...}
        """
        data = data.strip()
        if not data:
            return []

        # 1. Attempt standard JSON parsing (Array or single Object)
        try:
            parsed = json.loads(data)
            if isinstance(parsed, list): return parsed
            if isinstance(parsed, dict): return [parsed]
        except json.JSONDecodeError:
            pass

        # 2. Attempt parsing as concatenated objects (common with Shortcuts "Combine Text")
        tasks = []
        decoder = json.JSONDecoder()
        pos = 0
        while pos < len(data):
            try:
                # Skip whitespace/junk
                while pos < len(data) and data[pos] not in '{[':
                    pos += 1
                if pos >= len(data): break
                
                obj, new_pos = decoder.raw_decode(data, pos)
                if isinstance(obj, list):
                    tasks.extend(obj)
                else:
                    tasks.append(obj)
                pos = new_pos
            except (json.JSONDecodeError, ValueError):
                # If we hit an error, skip one char and try again
                pos += 1
        
        if not tasks:
            # Emergency log for debugging
            log_path = '/home/fish/.config/quickshell/data/last_failed_request.raw'
            with open(log_path, 'w', encoding='utf-8') as f:
                f.write(data)
            print(f"Warning: Parser failed to find any objects. Raw body saved to {log_path}")
            
        return tasks

    def process_and_save(self, new_tasks):
        # 1. Transform new tasks
        transformed_new = {}
        for task in new_tasks:
            try:
                # Expecting format: {"title": "...", "list": "...", "datetime": "2026-04-19T07:00:00+03:00"}
                dt_str = task.get('datetime')
                if not dt_str:
                    continue
                
                dt = datetime.fromisoformat(dt_str)
                date_key = dt.strftime("%Y-%m-%d")
                time_val = dt.strftime("%H:%M")
                
                task_item = {
                    "title": task.get('title', 'Untitled'),
                    "list": task.get('list', 'Reminders'),
                    "time": time_val
                }
                
                if date_key not in transformed_new:
                    transformed_new[date_key] = []
                transformed_new[date_key].append(task_item)
            except Exception as e:
                print(f"Skipping malformed task: {task}. Error: {e}")

        # 2. Read existing data
        existing_data = {}
        if os.path.exists(DATA_FILE):
            try:
                with open(DATA_FILE, 'r', encoding='utf-8') as f:
                    existing_data = json.load(f)
            except Exception as e:
                print(f"Warning: Could not read existing file: {e}")

        # 3. Merge data
        added_count = 0
        for date_key, tasks in transformed_new.items():
            if date_key not in existing_data:
                existing_data[date_key] = []
            
            for task in tasks:
                # Simple deduplication based on title, list, and time
                is_duplicate = any(
                    ext['title'] == task['title'] and 
                    ext['list'] == task['list'] and 
                    ext['time'] == task['time']
                    for ext in existing_data[date_key]
                )
                if not is_duplicate:
                    existing_data[date_key].append(task)
                    added_count += 1
            
            # Sort tasks by time for each date
            existing_data[date_key].sort(key=lambda x: x['time'])

        # 4. Atomic write
        self.atomic_write(DATA_FILE, existing_data)
        return f"Processed {len(new_tasks)} items, added {added_count} new unique tasks."

    def atomic_write(self, filepath, data):
        dir_name = os.path.dirname(filepath)
        if not os.path.exists(dir_name):
            os.makedirs(dir_name, exist_ok=True)
            
        # Use tempfile to write atomized
        fd, temp_path = tempfile.mkstemp(dir=dir_name, prefix=".events_tmp_")
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            # Atomic replace
            os.replace(temp_path, filepath)
            # Ensure proper permissions (optional, but good for local config)
            os.chmod(filepath, 0o644)
        except Exception:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise

def run():
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, WebhookHandler)
    print(f"Starting Apple Reminders Webhook Server on {HOST}:{PORT}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()

if __name__ == '__main__':
    run()
