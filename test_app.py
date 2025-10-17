#!/usr/bin/env python3
"""
Test script to interact with the iOS app and verify functionality
"""
import subprocess
import time
import json

def run_simulator_command(cmd):
    """Run a simulator command and return the output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout, result.stderr
    except Exception as e:
        return "", str(e)

def test_app_functionality():
    """Test the app's core functionality"""
    print("🧪 Testing Focusmate iOS App Functionality")
    print("=" * 50)
    
    # 1. Check if app is running
    print("1. Checking if app is running...")
    stdout, stderr = run_simulator_command("xcrun simctl list devices | grep 'iPhone 17 Pro'")
    if "iPhone 17 Pro" in stdout:
        print("✅ iPhone 17 Pro simulator is available")
    else:
        print("❌ iPhone 17 Pro simulator not found")
        return
    
    # 2. Check app installation
    print("\n2. Checking app installation...")
    stdout, stderr = run_simulator_command("xcrun simctl listapps booted | grep focusmate")
    if "focusmate" in stdout:
        print("✅ Focusmate app is installed")
    else:
        print("❌ Focusmate app not found")
        return
    
    # 3. Check app process
    print("\n3. Checking app process...")
    stdout, stderr = run_simulator_command("xcrun simctl spawn booted ps aux | grep focusmate")
    if "focusmate" in stdout:
        print("✅ Focusmate app is running")
    else:
        print("❌ Focusmate app not running")
        return
    
    # 4. Get app logs
    print("\n4. Getting recent app logs...")
    stdout, stderr = run_simulator_command("xcrun simctl spawn booted log show --last 1m --predicate 'process == \"focusmate\"' --style compact")
    if stdout:
        print("📱 Recent app logs:")
        print(stdout[-500:])  # Last 500 characters
    else:
        print("No recent logs found")
    
    print("\n" + "=" * 50)
    print("🎯 App testing completed!")
    print("\nTo manually test the app:")
    print("1. Open the app on the simulator")
    print("2. Sign in with your credentials")
    print("3. Navigate to a list")
    print("4. Try to create a new task")
    print("5. Check the console for any errors")

if __name__ == "__main__":
    test_app_functionality()
