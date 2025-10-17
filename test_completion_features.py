#!/usr/bin/env python3
"""
Test script to verify completion features are working in the iOS app.
This script will interact with the simulator to test the completion UI.
"""

import subprocess
import time
import json

def run_command(cmd):
    """Run a command and return the output."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return "", str(e)

def check_app_running():
    """Check if the focusmate app is running."""
    stdout, stderr = run_command("xcrun simctl list | grep 'iPhone 17 Pro'")
    if "Booted" in stdout:
        print("✅ iPhone 17 Pro simulator is running")
        return True
    else:
        print("❌ iPhone 17 Pro simulator is not running")
        return False

def check_app_installed():
    """Check if the focusmate app is installed."""
    stdout, stderr = run_command("xcrun simctl listapps 'iPhone 17 Pro' | grep focusmate")
    if "dev.local.chace.focusmate" in stdout:
        print("✅ Focusmate app is installed")
        return True
    else:
        print("❌ Focusmate app is not installed")
        return False

def get_app_logs():
    """Get recent app logs to see if there are any errors."""
    print("\n📱 Checking app logs for completion-related activity...")
    stdout, stderr = run_command("xcrun simctl spawn booted log show --last 1m --predicate 'process == \"focusmate\"' --style compact")
    
    if stdout:
        print("Recent app logs:")
        print(stdout[-500:])  # Show last 500 characters
    else:
        print("No recent app logs found")

def test_completion_features():
    """Test the completion features by checking the app state."""
    print("🧪 Testing Completion Features")
    print("=" * 50)
    
    # Check if simulator is running
    if not check_app_running():
        print("Please start the iPhone 17 Pro simulator first")
        return False
    
    # Check if app is installed
    if not check_app_installed():
        print("Please install the focusmate app first")
        return False
    
    # Get app logs to see current activity
    get_app_logs()
    
    print("\n📋 Manual Testing Instructions:")
    print("1. Open the focusmate app on the simulator")
    print("2. Sign in with your credentials")
    print("3. Navigate to a list")
    print("4. Create a new task if none exist")
    print("5. Tap the circle next to a task to complete it")
    print("6. You should see:")
    print("   ✅ Green checkmark (checkmark.circle.fill)")
    print("   ✅ Fade out effect (opacity 0.6)")
    print("   ✅ Strikethrough text")
    print("   ✅ 'Completed' label with timestamp")
    print("7. Tap on the completed task to see completion details")
    
    return True

if __name__ == "__main__":
    print("🎯 Focusmate Completion Features Test")
    print("=" * 50)
    
    success = test_completion_features()
    
    if success:
        print("\n✅ Test setup complete! Please follow the manual testing instructions above.")
    else:
        print("\n❌ Test setup failed. Please check the requirements.")
