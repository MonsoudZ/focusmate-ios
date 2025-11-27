#!/usr/bin/env python3
"""
Script to wrap print statements in #if DEBUG blocks for production builds
"""

import os
import re
from pathlib import Path

def process_swift_file(filepath):
    """Process a Swift file to wrap print statements in DEBUG blocks"""
    with open(filepath, 'r') as f:
        content = f.read()

    original_content = content
    lines = content.split('\n')
    new_lines = []
    i = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Check if line contains a print statement
        if 'print(' in line and not stripped.startswith('//'):
            # Check if already wrapped in #if DEBUG
            already_wrapped = False
            if i > 0 and '#if DEBUG' in lines[i-1]:
                already_wrapped = True

            if not already_wrapped:
                indent = len(line) - len(line.lstrip())
                indent_str = ' ' * indent

                # Wrap the print statement
                new_lines.append(f"{indent_str}#if DEBUG")
                new_lines.append(line)
                new_lines.append(f"{indent_str}#endif")
                i += 1
                continue

        new_lines.append(line)
        i += 1

    new_content = '\n'.join(new_lines)

    # Only write if content changed
    if new_content != original_content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        return True
    return False

def main():
    """Process all Swift files in the Focusmate directory"""
    focusmate_dir = Path('focusmate/Focusmate')

    if not focusmate_dir.exists():
        print(f"❌ Directory not found: {focusmate_dir}")
        return

    swift_files = list(focusmate_dir.rglob('*.swift'))
    modified_count = 0

    print(f"🔍 Found {len(swift_files)} Swift files")
    print(f"🔧 Wrapping print statements in #if DEBUG blocks...\n")

    for filepath in swift_files:
        if process_swift_file(filepath):
            modified_count += 1
            print(f"✅ Modified: {filepath}")

    print(f"\n✨ Complete! Modified {modified_count} files")

if __name__ == '__main__':
    main()
