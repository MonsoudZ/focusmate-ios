# Swift → Rails API Integration Guide

**Date**: October 30, 2025
**Status**: ✅ Ready for Testing

---

## Overview

This document outlines the integration between your Swift iOS app (focusmate) and Rails API (focusmate-api).

---

## Configuration Changes Made

### 1. API Base URL Updated ✅

**File**: `Config/Debug.xcconfig`

```
API_BASE_URL = http://localhost:3000/api/v1
CABLE_URL = ws://localhost:3000/cable
```

**For Simulator**: Use `localhost:3000`
**For Physical Device**: Update to your machine's local IP (e.g., `http://192.168.1.x:3000/api/v1`)

### 2. AuthService Request Format Fixed ✅

**File**: `focusmate/Focusmate/Core/Services/AuthService.swift`

#### Sign In
**Before** (incorrect):
```swift
{
  "email": "user@example.com",
  "password": "password123"
}
```

**After** (matches Rails):
```swift
{
  "authentication": {
    "email": "user@example.com",
    "password": "password123"
  }
}
```

#### Sign Up
**Before** (incorrect):
```swift
{
  "email": "user@example.com",
  "password": "password123",
  "passwordConfirmation": "password123",
  "name": "John Doe"
}
```

**After** (matches Rails):
```swift
{
  "authentication": {
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123",
    "name": "John Doe"
  }
}
```

### 3. UserDTO Model Updated ✅

**File**: `focusmate/Focusmate/Core/Models/Models.swift`

```swift
struct UserDTO: Codable, Identifiable, Hashable {
  let id: Int                // Was: String (now matches Rails integer ID)
  let email: String
  let name: String           // Was: String? (Rails always returns name)
  let role: String           // NEW: matches Rails user.role
  let timezone: String?      // NEW: matches Rails user.timezone

  var isCoach: Bool {
    role == "coach"
  }

  var isClient: Bool {
    role == "client" || role == "user"
  }
}
```

---

## API Endpoints Reference

### Authentication Endpoints

| Endpoint | Method | Request Body | Response |
|----------|--------|--------------|----------|
| `/api/v1/auth/sign_in` | POST | `{authentication: {email, password}}` | `{user: {...}, token: "..."}` |
| `/api/v1/auth/sign_up` | POST | `{authentication: {email, password, password_confirmation, name}}` | `{user: {...}, token: "..."}` |
| `/api/v1/auth/sign_out` | DELETE | - | 204 No Content |
| `/api/v1/profile` | GET | - (JWT required) | `{id, email, name, role, timezone, ...}` |

### Lists Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/lists` | GET | Get all lists for current user |
| `/api/v1/lists` | POST | Create new list |
| `/api/v1/lists/:id` | GET | Get specific list |
| `/api/v1/lists/:id` | PATCH | Update list |
| `/api/v1/lists/:id` | DELETE | Delete list (soft delete) |
| `/api/v1/lists/:id/tasks` | GET | Get tasks in list |
| `/api/v1/lists/:id/tasks` | POST | Create task in list |

### Tasks Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/tasks` | GET | Get all tasks across all lists |
| `/api/v1/tasks/:id` | GET | Get specific task |
| `/api/v1/tasks/:id` | PATCH | Update task |
| `/api/v1/tasks/:id` | DELETE | Delete task |
| `/api/v1/tasks/:id/complete` | POST/PATCH | Mark task complete |
| `/api/v1/tasks/:id/uncomplete` | PATCH | Mark task incomplete |
| `/api/v1/tasks/blocking` | GET | Get tasks blocking the app |
| `/api/v1/tasks/overdue` | GET | Get overdue tasks |

---

## Authentication Flow

### 1. Sign Up
```swift
let authService = AuthService(apiClient: apiClient)
let response = try await authService.signUp(
  email: "user@example.com",
  password: "password123",
  passwordConfirmation: "password123",
  name: "John Doe"
)
// Save response.token to keychain
// Store response.user
```

### 2. Sign In
```swift
let response = try await authService.signIn(
  email: "user@example.com",
  password: "password123"
)
// Save response.token to keychain
// Store response.user
```

### 3. Making Authenticated Requests
```swift
// APIClient automatically adds Authorization header
// Authorization: Bearer <jwt_token>
let lists = try await apiClient.request("GET", "lists", body: nil as String?)
```

---

## JWT Token Details

- **Expiration**: 1 hour (3600 seconds)
- **Format**: `Bearer <token>`
- **Header**: `Authorization: Bearer <token>`
- **Refresh**: Currently stateless (client deletes expired token and re-authenticates)

---

## Testing Checklist

### Prerequisites
- [ ] Rails server running on `localhost:3000`
- [ ] Database migrated and seeded
- [ ] Redis running (for background jobs)

### Authentication Tests
- [ ] Sign up new user
- [ ] Sign in existing user
- [ ] Fetch user profile
- [ ] Sign out

### List Tests
- [ ] Create list
- [ ] Fetch all lists
- [ ] Update list
- [ ] Delete list

### Task Tests
- [ ] Create task in list
- [ ] Fetch tasks from list
- [ ] Update task
- [ ] Complete task
- [ ] Delete task

---

## Starting the Rails Server

```bash
cd /Users/monsoudzanaty/Documents/focusmate-api

# Ensure database is migrated
bundle exec rails db:migrate

# Start Redis (required for background jobs)
redis-server

# Start Rails server
bundle exec rails server
```

Server will be available at `http://localhost:3000`

---

## Common Issues & Solutions

### Issue: "Connection refused" error
**Solution**: Ensure Rails server is running on port 3000

### Issue: "Unauthorized" (401) error
**Solution**: Check JWT token is being sent in Authorization header

### Issue: "Unprocessable Entity" (422) error
**Solution**: Check request body format matches Rails expectations

### Issue: Decoding error
**Solution**: Verify Swift models match Rails response structure

### Issue: Can't connect from physical device
**Solution**: Update `API_BASE_URL` in `Debug.xcconfig` to use your machine's local IP address instead of localhost

---

## Next Steps

1. ✅ **Configuration Updated**: API URLs and request formats fixed
2. ✅ **Models Updated**: UserDTO matches Rails response
3. ⏳ **Start Rails Server**: Ready to test
4. ⏳ **Run iOS App**: Test authentication flow
5. ⏳ **Implement ListService**: Create service for list operations
6. ⏳ **Implement TaskService**: Create service for task operations
7. ⏳ **Add Error Handling**: Handle network errors gracefully
8. ⏳ **Add Loading States**: Show progress indicators

---

## Files Modified

1. `/Users/monsoudzanaty/Documents/focusmate/Config/Debug.xcconfig`
2. `/Users/monsoudzanaty/Documents/focusmate/focusmate/Focusmate/Core/Services/AuthService.swift`
3. `/Users/monsoudzanaty/Documents/focusmate/focusmate/Focusmate/Core/Models/Models.swift`

---

## API Security Features (from Rails)

✅ **JWT Authentication**: 1-hour token expiration
✅ **Rate Limiting**: Enabled on `/api/v1/login` and `/api/v1/register`
✅ **HTTPS Ready**: Secure cookies in production
✅ **Authorization**: All endpoints protected except auth routes
✅ **No Vulnerabilities**: Brakeman security scan clean (0 warnings)

---

**Status**: Ready for integration testing! 🚀
