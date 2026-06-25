import os
import glob

def rename_content(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Skipping {filepath} due to read error: {e}")
        return

    new_content = content.replace('Pebble', 'Avelo').replace('pebble', 'avelo')
    
    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        if '.git' in root or 'build' in root or '.dart_tool' in root:
            continue
        for file in files:
            filepath = os.path.join(root, file)
            # Only process text files
            if filepath.endswith(('.dart', '.md', '.yaml', '.txt', '.cc', '.cpp', '.h', '.plist', '.pbxproj', '.xcconfig', '.xcscheme', '.json', '.html', '.rc', '.xml', '.kt', '.kts')):
                rename_content(filepath)

if __name__ == '__main__':
    project_root = '/home/grey/nolio'
    process_directory(project_root)
    
    # Also handle specific file and directory renames
    theme_old = os.path.join(project_root, 'lib/theme/pebble_theme.dart')
    theme_new = os.path.join(project_root, 'lib/theme/avelo_theme.dart')
    if os.path.exists(theme_old):
        os.rename(theme_old, theme_new)
        print(f"Renamed {theme_old} to {theme_new}")
        
    kt_old_dir = os.path.join(project_root, 'android/app/src/main/kotlin/com/example/pebble')
    kt_new_dir = os.path.join(project_root, 'android/app/src/main/kotlin/com/example/avelo')
    if os.path.exists(kt_old_dir):
        os.makedirs(kt_new_dir, exist_ok=True)
        os.rename(os.path.join(kt_old_dir, 'MainActivity.kt'), os.path.join(kt_new_dir, 'MainActivity.kt'))
        os.rmdir(kt_old_dir)
        print(f"Moved MainActivity.kt to {kt_new_dir}")
