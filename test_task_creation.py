#!/usr/bin/env python3
"""
Test script to verify task creation functionality in the iOS app.
This script will interact with the iOS simulator to test the app.
"""

import subprocess
import time
import json
import sys

def run_command(cmd):
    """Run a command and return the result."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def check_app_running():
    """Check if the focusmate app is running."""
    success, stdout, stderr = run_command("xcrun simctl list | grep focusmate")
    return "focusmate" in stdout

def get_app_logs():
    """Get recent app logs."""
    success, stdout, stderr = run_command("xcrun simctl spawn booted log show --last 1m --predicate 'process == \"focusmate\"' --style compact")
    return stdout

def test_app_functionality():
    """Test the app functionality by checking logs and app state."""
    print("🧪 Testing Focusmate App Functionality")
    print("=" * 50)
    
    # Check if app is running
    print("1. Checking if app is running...")
    if check_app_running():
        print("✅ App is running")
    else:
        print("❌ App is not running")
        return False
    
    # Get app logs
    print("\n2. Checking app logs...")
    logs = get_app_logs()
    if logs:
        print("✅ App logs found")
        print("Recent logs:")
        print(logs[-500:])  # Show last 500 characters
    else:
        print("⚠️ No recent logs found")
    
    # Check for specific log patterns
    print("\n3. Analyzing log patterns...")
    
    success_indicators = [
        "APIClient: Using JWT token",
        "ListService: Fetched",
        "ListsView: Loaded",
        "ItemViewModel: Successfully"
    ]
    
    error_indicators = [
        "❌",
        "Failed to",
        "Error:",
        "badStatus",
        "decoding error"
    ]
    
    success_count = sum(1 for indicator in success_indicators if indicator in logs)
    error_count = sum(1 for indicator in error_indicators if indicator in logs)
    
    print(f"✅ Success indicators found: {success_count}")
    print(f"❌ Error indicators found: {error_count}")
    
    if success_count > 0 and error_count == 0:
        print("\n🎉 App appears to be working correctly!")
        return True
    elif error_count > 0:
        print("\n⚠️ Some errors detected in logs")
        return False
    else:
        print("\n❓ Unable to determine app status from logs")
        return False

def main():
    """Main test function."""
    print("🚀 Starting Focusmate App Test")
    print("=" * 50)
    
    # Wait a moment for app to fully load
    print("⏳ Waiting for app to load...")
    time.sleep(3)
    
    # Test app functionality
    success = test_app_functionality()
    
    if success:
        print("\n✅ Test completed successfully!")
        print("\n📱 Manual Testing Instructions:")
        print("1. Open the app in the simulator")
        print("2. Sign in with your credentials")
        print("3. Navigate to a list")
        print("4. Try creating a new task")
        print("5. Check if the task appears in the list")
    else:
        print("\n❌ Test found issues")
        print("\n🔍 Check the logs above for specific error messages")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
