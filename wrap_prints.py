#!/usr/bin/env python3
"""
Wrap print statements in #if DEBUG blocks for production builds.
Keeps critical error prints visible in production.
"""

import os
import re
from pathlib import Path

# Print patterns that should remain visible in production (critical errors)
PRODUCTION_PATTERNS = [
    'CRITICAL',
    'FATAL',
    '❌ ERROR',
    'App will not function',
]

def should_keep_in_production(line):
    """Check if a print statement should remain in production builds"""
    for pattern in PRODUCTION_PATTERNS:
        if pattern in line:
            return True
    return False

def is_already_wrapped(lines, index):
    """Check if print at index is already wrapped in #if DEBUG"""
    # Check previous lines for #if DEBUG
    for i in range(max(0, index - 5), index):
        if '#if DEBUG' in lines[i]:
            # Check if there's a #endif after our print
            for j in range(index + 1, min(len(lines), index + 5)):
                if '#endif' in lines[j]:
                    return True
    return False

def process_file(filepath):
    """Process a single Swift file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    modified = False
    new_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check if this line has a print statement
        if 'print(' in line and not line.strip().startswith('//'):
            # Don't wrap if already in DEBUG block or if it's a critical error
            if is_already_wrapped(lines, i) or should_keep_in_production(line):
                new_lines.append(line)
                i += 1
                continue

            # Get indentation
            indent = len(line) - len(line.lstrip())
            spaces = ' ' * indent

            # Wrap in DEBUG block
            new_lines.append(f"{spaces}#if DEBUG\n")
            new_lines.append(line)
            new_lines.append(f"{spaces}#endif\n")
            modified = True
            i += 1
            continue

        new_lines.append(line)
        i += 1

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        return True

    return False

def main():
    focusmate_dir = Path('focusmate/Focusmate')

    if not focusmate_dir.exists():
        print("❌ Focusmate directory not found")
        return

    swift_files = list(focusmate_dir.rglob('*.swift'))
    modified_files = []

    print(f"🔍 Processing {len(swift_files)} Swift files...")

    for filepath in swift_files:
        try:
            if process_file(filepath):
                modified_files.append(filepath)
                print(f"✅ {filepath.relative_to('focusmate/Focusmate')}")
        except Exception as e:
            print(f"❌ Error processing {filepath}: {e}")

    print(f"\n✨ Modified {len(modified_files)} files")
    print(f"📊 Wrapped ~{len(modified_files) * 3} print statements in #if DEBUG blocks")

if __name__ == '__main__':
    main()
