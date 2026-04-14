#!/usr/bin/env python3
import json
import os
import tempfile
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime

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

        print(post_data)

        try:
            print(f"\n--- Получен запрос от iPhone ---")
            
            tasks = self.parse_incoming_data(post_data)
            print(f"[!] Найдено задач после парсинга: {len(tasks)}")
            
            status = self.process_and_save(tasks)
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success"}).encode('utf-8'))
            
        except Exception as e:
            print(f"Критическая ошибка сервера: {e}")
            self.send_response(500)
            self.end_headers()

    def parse_incoming_data(self, data):
        tasks = []
        decoder = json.JSONDecoder()
        
        # Убираем лишние пробелы по краям
        data = data.strip()
        
        while data:
            data = data.strip()
            if not data:
                break
                
            try:
                # Декодер находит ПЕРВЫЙ валидный кусок JSON и возвращает сам объект + индекс, где он закончился
                obj, idx = decoder.raw_decode(data)
                
                if isinstance(obj, list):
                    tasks.extend(obj)
                elif isinstance(obj, dict):
                    tasks.append(obj)
                    
                # Отрезаем распарсенный кусок и идем дальше
                data = data[idx:]
                
            except json.JSONDecodeError:
                # Если питон подавился (например, между объектами затесался мусор или запятая)
                # тупо ищем следующую открывающую скобку '{' и начинаем с нее
                next_bracket = data.find('{', 1)
                if next_bracket != -1:
                    data = data[next_bracket:]
                else:
                    break
                    
        return tasks


    def process_and_save(self, new_tasks):
        transformed_new = {}
        processed_count = 0
        
        for task in new_tasks:
            try:
                dt_str = task.get('datetime') or task.get('time') or task.get('date')
                if not dt_str:
                    print(f"[-] Пропущена задача (нет даты): {task.get('title')}")
                    continue
                
                # Фикс часового пояса Apple
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
                processed_count += 1
                print(f"[+] Успешно обработана: {task_item['title']} (на {date_key})")
                
            except Exception as e:
                print(f"Ошибка при обработке задачи {task}: {e}")

        # Сортируем внутри каждого дня по времени
        for date_key in transformed_new:
            transformed_new[date_key].sort(key=lambda x: x['time'])

        self.atomic_write(DATA_FILE, transformed_new)
        print(f"[OK] Файл events.json перезаписан. Всего сохранено задач: {processed_count}")
        return "OK"

    def atomic_write(self, filepath, data):
        dir_name = os.path.dirname(filepath)
        os.makedirs(dir_name, exist_ok=True)
        fd, temp_path = tempfile.mkstemp(dir=dir_name, prefix=".events_tmp_")
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            os.replace(temp_path, filepath)
            os.chmod(filepath, 0o644)
        except Exception:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise

if __name__ == '__main__':
    server_address = (HOST, PORT)
    httpd = HTTPServer(server_address, WebhookHandler)
    print(f"Сервер запущен на порту {PORT}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        httpd.server_close()