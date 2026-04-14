#!/usr/bin/env python3
import json
import os
import tempfile
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

# Configuration
HOST = '0.0.0.0'
PORT = 8081
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
        data = data.strip()
        if not data:
            return []

        # 1. МАГИЯ: Принудительно вставляем запятые между склеенными объектами
        # {"a":1}{"b":2} мгновенно превращается в {"a":1},{"b":2}
        fixed_data = re.sub(r'\}\s*\{', '},{', data)
        
        # 2. Оборачиваем всё это в правильный массив
        if not fixed_data.startswith('['):
            fixed_data = f"[{fixed_data}]"
            
        try:
            parsed = json.loads(fixed_data)
            if isinstance(parsed, list):
                # На всякий случай: защита от двойного массива [ [{...}] ]
                if len(parsed) > 0 and isinstance(parsed[0], list):
                    return parsed[0]
                return parsed
        except Exception as e:
            print(f"Ошибка парсинга: {e}\nПопытался распарсить: {fixed_data}")
            return []
            
        return []

    def process_and_save(self, new_tasks):
        transformed_new = {}
        for task in new_tasks:
            try:
                dt_str = task.get('datetime') or task.get('time') or task.get('date')
                if not dt_str:
                    continue
                
                dt_str = dt_str.replace('Z', '+00:00')
                dt = datetime.fromisoformat(dt_str)
                
                date_key = dt.strftime("%Y-%m-%d")
                time_val = dt.strftime("%H:%M")
                
                task_item = {
                    "title": task.get('title', 'Без названия'),
                    "list": task.get('list', 'Reminders'),
                    "time": time_val
                }
                
                if date_key not in transformed_new:
                    transformed_new[date_key] = []
                transformed_new[date_key].append(task_item)
            except Exception as e:
                print(f"Ошибка задачи: {e}")

        # ПОЛНАЯ ПЕРЕЗАПИСЬ
        # Сортируем по времени и полностью перезаписываем файл,
        # чтобы синхронизировать удаления.
        for date_key in transformed_new:
            transformed_new[date_key].sort(key=lambda x: x['time'])

        self.atomic_write(DATA_FILE, transformed_new)
        return f"Успешно сохранено {len(new_tasks)} задач."

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
