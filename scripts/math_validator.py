import os
import sys
import glob
import re
import shutil
import json
import argparse
from datetime import datetime

NOTES_DIR = os.path.expanduser("~/Documents/mathfuck/Syncing/Математический анализ/4 семестр")
SNAPSHOT_FILE = "/tmp/math_snapshot.md"
STATS_FILE = os.path.expanduser("~/.config/quickshell/data/math_stats.json")
RECENT_SESSION_LIMIT = 7

def get_target_file():
    if not os.path.exists(NOTES_DIR):
        os.makedirs(NOTES_DIR)
        
    all_files = glob.glob(os.path.join(NOTES_DIR, "Лекция *.md"))
    
    if not all_files:
        # Если файлов нет совсем, создаем первый на сегодня
        today_str = datetime.now().strftime("%d.%m.%y")
        new_file = os.path.join(NOTES_DIR, f"Лекция 1 {today_str}.md")
        with open(new_file, "w", encoding="utf-8") as f:
            f.write(f"# Лекция 1 ({today_str})\n\n")
        return new_file
    
    # Парсим даты из названий файлов и ищем самую позднюю
    latest_file = None
    latest_date = None
    
    date_regex = re.compile(r"(\d{2}\.\d{2}\.\d{2})")
    
    for f in all_files:
        basename = os.path.basename(f)
        match = date_regex.search(basename)
        if match:
            try:
                # Парсим дату в формате ДД.ММ.ГГ
                file_date = datetime.strptime(match.group(1), "%d.%m.%y")
                if latest_date is None or file_date > latest_date:
                    latest_date = file_date
                    latest_file = f
            except ValueError:
                continue
                
    if latest_file:
        return latest_file
    
    # Если даты не распарсились, просто берем последний по алфавиту/созданию
    return sorted(all_files)[-1]

def default_stats():
    return {
        "total_chars": 0,
        "total_formulas": 0,
        "sessions_completed": 0,
        "streak_days": 0,
        "last_session_date": "",
        "recent_sessions": []
    }

def load_stats():
    os.makedirs(os.path.dirname(STATS_FILE), exist_ok=True)

    stats = default_stats()

    if os.path.exists(STATS_FILE):
        try:
            with open(STATS_FILE, "r", encoding="utf-8") as f:
                loaded_stats = json.load(f)

            if isinstance(loaded_stats, dict):
                stats.update(loaded_stats)
        except:
            pass

    if not isinstance(stats.get("recent_sessions"), list):
        stats["recent_sessions"] = []

    return stats

def save_stats(stats):
    os.makedirs(os.path.dirname(STATS_FILE), exist_ok=True)

    with open(STATS_FILE, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=4, ensure_ascii=False)

def do_sync():
    try:
        file_path = get_target_file()
        shutil.copy2(file_path, SNAPSHOT_FILE)
        # При успешном синке можно ничего не выводить или вывести JSON
        print(json.dumps({"status": "success", "file": file_path, "message": "Snapshot created."}))
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}))

def do_check():
    try:
        file_path = get_target_file()
        
        if not os.path.exists(SNAPSHOT_FILE):
             print(json.dumps({"error": "Snapshot not found in /tmp. Run script with --sync first."}))
             return
            
        with open(file_path, "r", encoding="utf-8") as f:
            current_content = f.read()
            
        with open(SNAPSHOT_FILE, "r", encoding="utf-8") as f:
            snapshot_content = f.read()
            
        # Считаем количество новых символов
        added_symbols = max(0, len(current_content) - len(snapshot_content))
        
        # Проверяем наличие LaTeX-формул
        has_latex = False
        latex_patterns = [r'\$', r'\\int', r'\\lim']
        
        # Мы можем искать формулы только в новом тексте, но для простоты поищем во всем файле
        # или лучше искать разницу. Ищем во всем тексте, так как задача звучит как "наличие LaTeX-формул".
        for pattern in latex_patterns:
            if re.search(pattern, current_content):
                has_latex = True
                break
                
        # Логика прогресса
        # Допустим, цель - написать 500 символов
        TARGET_SYMBOLS = 500.0
        progress = min(1.0, added_symbols / TARGET_SYMBOLS)
        
        # Логика готовности (например, написано больше 500 символов и есть хотя бы одна формула)
        is_ready = bool(progress >= 1.0 and has_latex)
        
        result = {
            "progress": round(progress, 2),
            "is_ready": is_ready,
            "added_symbols": added_symbols,
            "has_latex": has_latex
        }
        
        print(json.dumps(result))
    except Exception as e:
         print(json.dumps({"status": "error", "error": str(e)}))

def update_stats(added_chars, added_formulas):
    stats = load_stats()
    now = datetime.now()
    today_str = now.strftime("%Y-%m-%d")
    
    if stats["last_session_date"] == today_str:
        pass
    else:
        if stats["last_session_date"]:
            try:
                last_date = datetime.strptime(stats["last_session_date"], "%Y-%m-%d")
                today_date = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                diff = (today_date - last_date).days
                if diff == 1:
                    stats["streak_days"] += 1
                else:
                    stats["streak_days"] = 1
            except ValueError:
                stats["streak_days"] = 1
        else:
            stats["streak_days"] = 1
            
    stats["last_session_date"] = today_str
    stats["total_chars"] += added_chars
    stats["total_formulas"] += added_formulas
    stats["sessions_completed"] += 1
    stats["recent_sessions"] = (stats["recent_sessions"] + [{
        "date": today_str,
        "chars": added_chars,
        "formulas": added_formulas,
        "completed_at": now.strftime("%H:%M")
    }])[-RECENT_SESSION_LIMIT:]
    
    save_stats(stats)

    return stats

def do_stats():
    try:
        print(json.dumps(load_stats(), ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}))

def do_complete():
    try:
        file_path = get_target_file()
        
        if not os.path.exists(SNAPSHOT_FILE):
             print(json.dumps({"error": "Snapshot not found in /tmp. Run script with --sync first."}))
             return
            
        with open(file_path, "r", encoding="utf-8") as f:
            current_content = f.read()
            
        with open(SNAPSHOT_FILE, "r", encoding="utf-8") as f:
            snapshot_content = f.read()
            
        added_symbols = max(0, len(current_content) - len(snapshot_content))
        
        latex_patterns = [r'\$', r'\\int', r'\\lim']
        
        def count_formulas(content):
            count = 0
            for pattern in latex_patterns:
                # To prevent overlapping matches or infinite loops, use len(findall)
                try:
                    count += len(re.findall(pattern, content))
                except re.error:
                    pass
            return count
            
        current_formulas = count_formulas(current_content)
        snapshot_formulas = count_formulas(snapshot_content)
        added_formulas = max(0, current_formulas - snapshot_formulas)
        
        stats = update_stats(added_symbols, added_formulas)
        
        if os.path.exists(SNAPSHOT_FILE):
            os.remove(SNAPSHOT_FILE)
            
        result = {
            "status": "success",
            "message": "Session completed.",
            "stats": stats
        }
        
        print(json.dumps(result))
    except Exception as e:
         print(json.dumps({"status": "error", "error": str(e)}))

def main():
    parser = argparse.ArgumentParser(description="Math Notes Validator")
    parser.add_argument("--sync", action="store_true", help="Создать копию текущего файла в /tmp/")
    parser.add_argument("--check", action="store_true", help="Сравнить файл с копией и вывести статистику в формате JSON")
    parser.add_argument("--complete", action="store_true", help="Завершить сессию, обновить статистику и удалить /tmp/math_snapshot.md")
    parser.add_argument("--stats", action="store_true", help="Вывести накопленную статистику в формате JSON")
    
    args = parser.parse_args()
    
    if args.sync:
        do_sync()
    elif args.check:
        do_check()
    elif args.complete:
        do_complete()
    elif args.stats:
        do_stats()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
