#!/usr/bin/env python3
"""
Test script to interact with the iOS app using simulator commands
"""
import subprocess
import time
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

def test_app_automation():
    """Test the app using simulator automation"""
    print("🤖 Testing Focusmate App with Automation")
    print("=" * 60)
    
    # 1. Check if app is running
    print("1. Checking app status...")
    stdout, stderr = run_command("xcrun simctl spawn booted ps aux | grep focusmate")
    if "focusmate" not in stdout:
        print("❌ App not running. Launching...")
        stdout, stderr = run_command("xcrun simctl launch booted dev.local.chace.focusmate")
        time.sleep(3)
    else:
        print("✅ App is running")
    
    # 2. Get app logs to see what's happening
    print("\n2. Analyzing app logs...")
    stdout, stderr = run_command("xcrun simctl spawn booted log show --last 1m --predicate 'process == \"focusmate\"' --style compact")
    
    # Look for our debug messages
    debug_messages = []
    api_calls = []
    errors = []
    
    for line in stdout.split('\n'):
        if '🔍' in line or '✅' in line or '❌' in line or '🧩' in line:
            debug_messages.append(line.strip())
        elif 'APIClient' in line or 'API' in line:
            api_calls.append(line.strip())
        elif 'error' in line.lower() or 'failed' in line.lower():
            errors.append(line.strip())
    
    print(f"📊 Found {len(debug_messages)} debug messages, {len(api_calls)} API calls, {len(errors)} errors")
    
    # 3. Show recent debug messages
    if debug_messages:
        print("\n🔍 Recent Debug Messages:")
        for msg in debug_messages[-10:]:
            print(f"  {msg}")
    
    # 4. Show API calls
    if api_calls:
        print("\n🌐 Recent API Calls:")
        for call in api_calls[-5:]:
            print(f"  {call}")
    
    # 5. Show errors
    if errors:
        print("\n❌ Recent Errors:")
        for error in errors[-5:]:
            print(f"  {error}")
    
    # 6. Analyze the state
    print("\n📊 App State Analysis:")
    
    # Check for authentication
    has_jwt = any('JWT' in line for line in debug_messages)
    if has_jwt:
        print("✅ Authentication: JWT token found")
    else:
        print("❌ Authentication: No JWT token found")
    
    # Check for list loading
    has_lists = any('ListService' in line for line in debug_messages)
    if has_lists:
        print("✅ List Loading: ListService activity detected")
    else:
        print("❌ List Loading: No ListService activity")
    
    # Check for item loading
    has_items = any('ItemService' in line for line in debug_messages)
    if has_items:
        print("✅ Item Loading: ItemService activity detected")
    else:
        print("❌ Item Loading: No ItemService activity")
    
    # Check for decoding errors
    has_decoding_errors = any('decoding' in line.lower() for line in errors)
    if has_decoding_errors:
        print("❌ Model Decoding: Decoding errors detected")
    else:
        print("✅ Model Decoding: No decoding errors")
    
    # Check for network errors
    has_network_errors = any('badStatus' in line for line in errors)
    if has_network_errors:
        print("❌ Network: API communication errors detected")
    else:
        print("✅ Network: No API communication errors")
    
    return {
        'debug_messages': len(debug_messages),
        'api_calls': len(api_calls),
        'errors': len(errors),
        'has_jwt': has_jwt,
        'has_lists': has_lists,
        'has_items': has_items,
        'has_decoding_errors': has_decoding_errors,
        'has_network_errors': has_network_errors
    }

def simulate_user_interaction():
    """Simulate user interactions with the app"""
    print("\n👆 Simulating User Interactions...")
    print("-" * 40)
    
    # Since we can't directly interact with the UI programmatically,
    # we'll provide instructions for manual testing
    print("📱 Manual Testing Instructions:")
    print("1. Open the Focusmate app on the simulator")
    print("2. If you see a sign-in screen, enter your credentials")
    print("3. Navigate to the Lists view")
    print("4. Tap on a list to open it")
    print("5. Try to create a new task/item")
    print("6. Check if the task appears in the list")
    
    print("\n🔍 What to look for:")
    print("- Authentication should work (JWT token in logs)")
    print("- Lists should load (ListService debug messages)")
    print("- Items should load (ItemService debug messages)")
    print("- No decoding errors in the console")
    print("- No network errors (badStatus)")
    
    print("\n📊 After testing, run this script again to see the results!")

if __name__ == "__main__":
    print("🧪 Focusmate App Testing Suite")
    print("=" * 60)
    
    # Test app automation
    results = test_app_automation()
    
    # Provide interaction instructions
    simulate_user_interaction()
    
    # Summary
    print("\n" + "=" * 60)
    print("📋 Test Summary:")
    print(f"  Debug Messages: {results['debug_messages']}")
    print(f"  API Calls: {results['api_calls']}")
    print(f"  Errors: {results['errors']}")
    print(f"  Authentication: {'✅' if results['has_jwt'] else '❌'}")
    print(f"  List Loading: {'✅' if results['has_lists'] else '❌'}")
    print(f"  Item Loading: {'✅' if results['has_items'] else '❌'}")
    print(f"  Decoding: {'✅' if not results['has_decoding_errors'] else '❌'}")
    print(f"  Network: {'✅' if not results['has_network_errors'] else '❌'}")
    
    print("\n🎯 Next Steps:")
    if results['has_decoding_errors']:
        print("  - Fix model decoding issues")
    if results['has_network_errors']:
        print("  - Check Rails API connection")
    if not results['has_jwt']:
        print("  - Check authentication flow")
    if not results['has_lists']:
        print("  - Check list loading functionality")
    if not results['has_items']:
        print("  - Check item loading functionality")
    
    if not any([results['has_decoding_errors'], results['has_network_errors']]) and results['has_jwt']:
        print("  🎉 App appears to be working correctly!")
