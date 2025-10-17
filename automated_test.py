#!/usr/bin/env python3
"""
Automated testing script for the Focusmate iOS app
"""
import subprocess
import time
import json
import os

def run_command(cmd, timeout=30):
    """Run a command with timeout"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return "", "Command timed out"
    except Exception as e:
        return "", str(e)

def create_ui_test_script():
    """Create a UI test script for the simulator"""
    test_script = """
    // UI Test Script for Focusmate App
    import XCTest
    
    class FocusmateUITest: XCTestCase {
        var app: XCUIApplication!
        
        override func setUp() {
            super.setUp()
            app = XCUIApplication()
            app.launch()
        }
        
        func testAppLaunch() {
            // Wait for app to launch
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        }
        
        func testSignIn() {
            // Look for sign-in elements
            let emailField = app.textFields["Email"]
            let passwordField = app.secureTextFields["Password"]
            let signInButton = app.buttons["Sign In"]
            
            if emailField.exists {
                emailField.tap()
                emailField.typeText("test@example.com")
                
                passwordField.tap()
                passwordField.typeText("password")
                
                signInButton.tap()
                
                // Wait for navigation
                sleep(2)
            }
        }
        
        func testNavigateToLists() {
            // Look for lists view
            let listsView = app.otherElements["ListsView"]
            if listsView.exists {
                listsView.tap()
            }
        }
        
        func testCreateTask() {
            // Look for create task button
            let createButton = app.buttons["Create Task"]
            if createButton.exists {
                createButton.tap()
                
                // Fill in task details
                let nameField = app.textFields["Task Name"]
                if nameField.exists {
                    nameField.tap()
                    nameField.typeText("Test Task")
                }
                
                let saveButton = app.buttons["Save"]
                if saveButton.exists {
                    saveButton.tap()
                }
            }
        }
    }
    """
    
    with open('/Users/monsoudzanaty/Documents/focusmate/FocusmateUITest.swift', 'w') as f:
        f.write(test_script)
    
    return '/Users/monsoudzanaty/Documents/focusmate/FocusmateUITest.swift'

def run_comprehensive_test():
    """Run a comprehensive test of the app"""
    print("🧪 Comprehensive Focusmate App Test")
    print("=" * 60)
    
    # 1. Ensure app is running
    print("1. Ensuring app is running...")
    stdout, stderr = run_command("xcrun simctl launch booted dev.local.chace.focusmate")
    time.sleep(5)
    
    # 2. Get comprehensive logs
    print("2. Collecting comprehensive logs...")
    stdout, stderr = run_command("xcrun simctl spawn booted log show --last 2m --predicate 'process == \"focusmate\"' --style compact")
    
    # 3. Analyze logs for our specific debug messages
    print("3. Analyzing logs for debug messages...")
    
    debug_patterns = {
        'JWT': r'JWT token',
        'ListService': r'ListService',
        'ItemService': r'ItemService',
        'APIClient': r'APIClient',
        'decoding': r'decoding',
        'badStatus': r'badStatus',
        'error': r'error',
        'success': r'✅',
        'failure': r'❌'
    }
    
    found_patterns = {}
    for pattern_name, pattern in debug_patterns.items():
        matches = [line for line in stdout.split('\n') if pattern in line]
        found_patterns[pattern_name] = matches
    
    # 4. Display results
    print("\n📊 Log Analysis Results:")
    print("-" * 40)
    
    for pattern_name, matches in found_patterns.items():
        if matches:
            print(f"✅ {pattern_name}: {len(matches)} occurrences")
            for match in matches[-3:]:  # Show last 3 matches
                print(f"   {match.strip()}")
        else:
            print(f"❌ {pattern_name}: No occurrences")
    
    # 5. Check for specific functionality
    print("\n🔍 Functionality Check:")
    print("-" * 40)
    
    has_jwt = len(found_patterns['JWT']) > 0
    has_list_service = len(found_patterns['ListService']) > 0
    has_item_service = len(found_patterns['ItemService']) > 0
    has_api_calls = len(found_patterns['APIClient']) > 0
    has_decoding_errors = len(found_patterns['decoding']) > 0
    has_network_errors = len(found_patterns['badStatus']) > 0
    
    print(f"Authentication: {'✅ Working' if has_jwt else '❌ Not detected'}")
    print(f"List Service: {'✅ Working' if has_list_service else '❌ Not detected'}")
    print(f"Item Service: {'✅ Working' if has_item_service else '❌ Not detected'}")
    print(f"API Calls: {'✅ Working' if has_api_calls else '❌ Not detected'}")
    print(f"Decoding: {'❌ Errors found' if has_decoding_errors else '✅ No errors'}")
    print(f"Network: {'❌ Errors found' if has_network_errors else '✅ No errors'}")
    
    # 6. Provide recommendations
    print("\n🎯 Recommendations:")
    print("-" * 40)
    
    if not has_jwt:
        print("- Check authentication flow - no JWT token found")
    if not has_list_service:
        print("- Check list loading - no ListService activity")
    if not has_item_service:
        print("- Check item loading - no ItemService activity")
    if not has_api_calls:
        print("- Check API communication - no APIClient activity")
    if has_decoding_errors:
        print("- Fix model decoding issues")
    if has_network_errors:
        print("- Check Rails API connection")
    
    if has_jwt and has_list_service and has_item_service and has_api_calls and not has_decoding_errors and not has_network_errors:
        print("🎉 App appears to be working correctly!")
    
    return {
        'has_jwt': has_jwt,
        'has_list_service': has_list_service,
        'has_item_service': has_item_service,
        'has_api_calls': has_api_calls,
        'has_decoding_errors': has_decoding_errors,
        'has_network_errors': has_network_errors
    }

def create_manual_test_guide():
    """Create a manual test guide"""
    guide = """
# Focusmate App Manual Testing Guide

## Prerequisites
1. Ensure the Rails API server is running
2. Ensure ngrok is running and accessible
3. Launch the iOS app in the simulator

## Test Steps

### 1. Authentication Test
- Open the app
- Look for sign-in screen
- Enter test credentials
- Check console for JWT token messages

### 2. List Loading Test
- After sign-in, navigate to lists view
- Check console for ListService debug messages
- Verify lists are displayed

### 3. Item Loading Test
- Tap on a list to open it
- Check console for ItemService debug messages
- Verify items are displayed

### 4. Item Creation Test
- Try to create a new task/item
- Check console for API calls
- Verify item appears in the list

## What to Look For

### Success Indicators
- ✅ JWT token in console
- ✅ ListService debug messages
- ✅ ItemService debug messages
- ✅ APIClient network calls
- ✅ No decoding errors
- ✅ No network errors

### Error Indicators
- ❌ No JWT token
- ❌ No ListService activity
- ❌ No ItemService activity
- ❌ Decoding errors
- ❌ Network errors (badStatus)

## Console Commands
```bash
# Monitor app logs
xcrun simctl spawn booted log stream --predicate 'process == "focusmate"' --style compact

# Get recent logs
xcrun simctl spawn booted log show --last 2m --predicate 'process == "focusmate"' --style compact
```
"""
    
    with open('/Users/monsoudzanaty/Documents/focusmate/MANUAL_TEST_GUIDE.md', 'w') as f:
        f.write(guide)
    
    print(f"\n📖 Manual test guide created: MANUAL_TEST_GUIDE.md")

if __name__ == "__main__":
    print("🚀 Starting Comprehensive App Test")
    print("=" * 60)
    
    # Run comprehensive test
    results = run_comprehensive_test()
    
    # Create manual test guide
    create_manual_test_guide()
    
    # Final summary
    print("\n" + "=" * 60)
    print("📋 Final Test Summary:")
    print(f"  Authentication: {'✅' if results['has_jwt'] else '❌'}")
    print(f"  List Service: {'✅' if results['has_list_service'] else '❌'}")
    print(f"  Item Service: {'✅' if results['has_item_service'] else '❌'}")
    print(f"  API Calls: {'✅' if results['has_api_calls'] else '❌'}")
    print(f"  Decoding: {'❌' if results['has_decoding_errors'] else '✅'}")
    print(f"  Network: {'❌' if results['has_network_errors'] else '✅'}")
    
    print("\n🎯 Next Steps:")
    print("1. Follow the manual test guide")
    print("2. Run this script again after testing")
    print("3. Check the console output for any issues")
    print("4. Report any errors or unexpected behavior")
