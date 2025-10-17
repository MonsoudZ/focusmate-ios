
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
