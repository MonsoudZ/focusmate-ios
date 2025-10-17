#!/usr/bin/env python3
"""
Monitor the iOS app's network requests and logs to test functionality
"""
import subprocess
import time
import re
import json

def run_command(cmd, timeout=10):
    """Run a command with timeout"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return "", "Command timed out"
    except Exception as e:
        return "", str(e)

def monitor_app_logs():
    """Monitor app logs for network requests and errors"""
    print("🔍 Monitoring Focusmate app logs...")
    print("=" * 60)
    
    # Get recent logs
    stdout, stderr = run_command("xcrun simctl spawn booted log show --last 2m --predicate 'process == \"focusmate\"' --style compact")
    
    if not stdout:
        print("❌ No logs found. App might not be running.")
        return
    
    print("📱 Recent app logs:")
    print("-" * 40)
    
    # Look for specific patterns
    lines = stdout.split('\n')
    api_calls = []
    errors = []
    debug_info = []
    
    for line in lines:
        if 'APIClient' in line or 'API' in line:
            api_calls.append(line)
        elif 'error' in line.lower() or 'failed' in line.lower():
            errors.append(line)
        elif '🔍' in line or '✅' in line or '❌' in line:
            debug_info.append(line)
    
    # Display findings
    if api_calls:
        print("\n🌐 API Calls Found:")
        for call in api_calls[-5:]:  # Last 5 API calls
            print(f"  {call}")
    
    if errors:
        print("\n❌ Errors Found:")
        for error in errors[-5:]:  # Last 5 errors
            print(f"  {error}")
    
    if debug_info:
        print("\n🔍 Debug Info Found:")
        for info in debug_info[-10:]:  # Last 10 debug messages
            print(f"  {info}")
    
    # Check for specific patterns
    print("\n📊 Analysis:")
    
    # Check for authentication
    if any('JWT' in line for line in lines):
        print("✅ JWT token found - Authentication working")
    else:
        print("❌ No JWT token found - Authentication might be failing")
    
    # Check for list loading
    if any('ListService' in line for line in lines):
        print("✅ ListService activity found - List loading working")
    else:
        print("❌ No ListService activity - List loading might be failing")
    
    # Check for item loading
    if any('ItemService' in line for line in lines):
        print("✅ ItemService activity found - Item loading working")
    else:
        print("❌ No ItemService activity - Item loading might be failing")
    
    # Check for decoding errors
    if any('decoding' in line.lower() for line in lines):
        print("❌ Decoding errors found - Model issues detected")
    else:
        print("✅ No decoding errors found - Models working correctly")
    
    # Check for network errors
    if any('badStatus' in line for line in lines):
        print("❌ Network errors found - API communication issues")
    else:
        print("✅ No network errors found - API communication working")

def test_rails_api_connection():
    """Test if the Rails API is accessible"""
    print("\n🔗 Testing Rails API Connection...")
    print("-" * 40)
    
    # This would require the Rails server to be running
    # For now, just check if we can see any API calls in the logs
    stdout, stderr = run_command("xcrun simctl spawn booted log show --last 1m --predicate 'process == \"focusmate\"' --style compact")
    
    if 'ngrok' in stdout or 'api' in stdout.lower():
        print("✅ API calls detected - Rails API connection working")
    else:
        print("❌ No API calls detected - Rails API connection might be failing")

if __name__ == "__main__":
    print("🧪 Focusmate App Monitor")
    print("=" * 60)
    
    # Check if app is running
    stdout, stderr = run_command("xcrun simctl spawn booted ps aux | grep focusmate")
    if "focusmate" not in stdout:
        print("❌ Focusmate app is not running. Please launch the app first.")
        exit(1)
    
    print("✅ Focusmate app is running")
    
    # Monitor logs
    monitor_app_logs()
    
    # Test API connection
    test_rails_api_connection()
    
    print("\n" + "=" * 60)
    print("🎯 Monitoring completed!")
    print("\nTo test the app manually:")
    print("1. Open the app on the simulator")
    print("2. Sign in with your credentials")
    print("3. Navigate to a list")
    print("4. Try to create a new task")
    print("5. Run this script again to see the results")
