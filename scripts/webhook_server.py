import http.server
import json
import os
import tempfile
import logging
from datetime import datetime

# Configuration
PORT = 8080
BIND_ADDRESS = '0.0.0.0'
DATA_FILE = '/home/fish/.config/quickshell/data/events.json'

# Setup logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

class RemindersHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Redirect http.server logs to our logger
        logger.info("%s - %s" % (self.address_string(), format % args))

    def do_POST(self):
        if self.path != '/sync':
            self.send_response(404)
            self.end_headers()
            return

        logger.debug(f"Headers: {self.headers}")
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)

        try:
            if not post_data:
                raise ValueError("Empty request body")

            # Auto-detect format
            if post_data.startswith(b'BEGIN:VCALENDAR') or post_data.startswith(b'BEGIN:VTODO'):
                logger.info("Detected iCal format")
                tasks = self.parse_ical(post_data.decode('utf-8'))
            else:
                logger.info("Detected JSON format")
                tasks = json.loads(post_data)
                
            if not isinstance(tasks, list):
                if isinstance(tasks, dict):
                    tasks = [tasks]
                else:
                    raise ValueError(f"Payload must be a list or object, got {type(tasks).__name__}")

            logger.info(f"Received {len(tasks)} tasks from {self.address_string()}")
            processed_data = self.process_tasks(tasks)
            self.atomic_write(processed_data)

            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "success", "count": len(tasks)}).encode())
            logger.info(f"Successfully synced {len(tasks)} tasks to {DATA_FILE}")
            
        except Exception as e:
            logger.error(f"Error processing request from {self.address_string()}: {str(e)}")
            logger.debug(f"Raw data received: {post_data!r}")
            self.send_response(400)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode())

    def parse_ical(self, data):
        """
        Simple iCal parser to extract tasks from VTODO blocks.
        """
        tasks = []
        current_task = None
        
        # Standardize lines (handle folded lines if any)
        lines = data.replace('\r\n ', '').replace('\n ', '').splitlines()
        
        for line in lines:
            line = line.strip()
            if not line: continue
            
            if line.startswith('BEGIN:VTODO'):
                current_task = {}
            elif current_task is not None:
                if line.startswith('END:VTODO'):
                    tasks.append(current_task)
                    current_task = None
                elif ':' in line:
                    key_part, value = line.split(':', 1)
                    key = key_part.split(';')[0] # Remove params like ;TZID=...
                    
                    if key == 'SUMMARY':
                        current_task['title'] = value
                    elif key in ('DUE', 'DTSTART'):
                        current_task['dueDate'] = value
                    elif key == 'X-APPLE-LIST-NAME':
                        current_task['list'] = value
        return tasks

    def process_tasks(self, tasks):
        """
        Transforms raw tasks into the target structure:
        { "YYYY-MM-DD": [ { "title": "...", "list": "...", "time": "HH:MM" } ] }
        """
        result = {}
        for task in tasks:
            title = task.get('title', 'No Title')
            list_name = task.get('list', 'Reminders')
            date_str = task.get('dueDate') or task.get('date')

            if not date_str:
                continue

            try:
                dt = None
                # Try parsing with various formats
                # 1. iCal format: 20260419T070000
                # 2. ISO with TZ
                # 3. ISO without Ms
                # 4. Simple date-time
                formats = (
                    "%Y%m%dT%H%M%S",        # iCal basic
                    "%Y-%m-%dT%H:%M:%S%z", # ISO with TZ
                    "%Y-%m-%dT%H:%M:%S",   # ISO
                    "%Y-%m-%d %H:%M:%S",
                    "%Y-%m-%d %H:%M"
                )
                
                clean_date = date_str.split('.')[0].replace('-', '').replace(':', '') if 'T' in date_str and len(date_str) < 20 else date_str.split('.')[0]
                
                # Special handling for iCal compact format vs ISO
                for fmt in formats:
                    try:
                        # For iCal compact, we need the version without separators
                        if fmt == "%Y%m%dT%H:%M:%S": continue # redundant
                        
                        test_str = date_str.split('.')[0]
                        if fmt == "%Y%m%dT%H:%M:%S": test_str = test_str.replace('-', '').replace(':', '')
                        
                        dt = datetime.strptime(test_str.replace('Z', ''), fmt.replace('%z', '') if '%z' not in fmt else fmt)
                        break
                    except:
                        continue
                
                if not dt:
                    # Fallback
                    dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))

                day_key = dt.strftime("%Y-%m-%d")
                time_str = dt.strftime("%H:%M")

                if day_key not in result:
                    result[day_key] = []
                
                result[day_key].append({
                    "title": title,
                    "list": list_name,
                    "time": time_str
                })
            except Exception as e:
                logger.warning(f"Failed to parse date '{date_str}': {e}")
                continue
        
        # Sort tasks within each day by time
        for day in result:
            result[day].sort(key=lambda x: x['time'])
            
        return result

    def atomic_write(self, data):
        dir_name = os.path.dirname(DATA_FILE)
        os.makedirs(dir_name, exist_ok=True)
        
        # Use tempfile to ensure atomic write
        fd, temp_path = tempfile.mkstemp(dir=dir_name, prefix='events_', suffix='.json')
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            os.replace(temp_path, DATA_FILE)
        except Exception as e:
            if os.path.exists(temp_path):
                os.remove(temp_path)
            raise e

def run():
    server_address = (BIND_ADDRESS, PORT)
    try:
        httpd = http.server.HTTPServer(server_address, RemindersHandler)
        logger.info(f"Starting webhook server on {BIND_ADDRESS}:{PORT}...")
        httpd.serve_forever()
    except Exception as e:
        logger.error(f"Server failed: {e}")

if __name__ == '__main__':
    run()
