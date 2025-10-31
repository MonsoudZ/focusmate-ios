# Focusmate iOS App - API Integration Audit Report

**Date**: October 31, 2025
**Auditor**: Claude Code
**Status**: 🔴 **CRITICAL ISSUES FOUND** - App will not work properly with API

---

## Executive Summary

The iOS SwiftUI app has been audited for API integration compatibility with the Rails backend. **Multiple critical issues were identified that will prevent the app from functioning correctly**. The app has duplicate API client implementations, mismatched data models, hardcoded URLs, and configuration inconsistencies that must be fixed before deployment.

**Severity Breakdown**:
- 🔴 **Critical Issues**: 8 (will break functionality)
- 🟡 **Major Issues**: 5 (will cause problems)
- 🟢 **Minor Issues**: 3 (improvements needed)

---

## 🔴 CRITICAL ISSUES (Must Fix)

### 1. **Multiple Conflicting API Client Implementations**

**Severity**: 🔴 CRITICAL

**Location**:
- `focusmate/Focusmate/Core/API/APIClient.swift`
- `focusmate/Focusmate/Core/API/NewAPIClient.swift`

**Problem**:
The app has TWO different API client implementations that work differently:

```swift
// OLD APIClient (used by AuthService, ItemService, ListService)
- Uses NetworkingProtocol wrapper
- Reads base URL from Info.plist: API_BASE_URL
- Token provided via closure callback
- Uses APIClient.encoder/decoder with convertToSnakeCase

// NEW APIClient (used by Repositories, AuthAPI)
- Direct URLSession implementation
- Reads base URL from APIEndpoints.swift enum
- Token stored in AuthSession actor
- Uses standard JSONEncoder/Decoder
```

**Impact**:
- Different services hit different base URLs
- Inconsistent authentication token management
- One may work while the other fails
- Difficult to debug and maintain

**Fix Required**:
1. Standardize on ONE API client implementation
2. Remove the duplicate
3. Update all services to use the same client
4. Ensure consistent URL configuration

---

### 2. **Hardcoded ngrok URL in WebSocket Manager**

**Severity**: 🔴 CRITICAL

**Location**: `focusmate/Focusmate/Core/Services/WebSocketManager.swift:33`

**Problem**:
```swift
guard let baseURL = URL(string: "wss://untampered-jong-harshly.ngrok-free.dev/cable") else {
```

The WebSocket URL is hardcoded and points to a temporary ngrok tunnel that:
- Will expire when the ngrok session ends
- Cannot be configured for different environments
- Does not match the Debug.xcconfig configuration

**Impact**:
- Real-time updates will completely fail
- WebSocket will never connect
- App will fall back to HTTP polling (30-second delay)
- Users won't see live task updates

**Fix Required**:
```swift
// Read from Info.plist or Bundle
guard let cableURLString = Bundle.main.object(forInfoDictionaryKey: "CABLE_URL") as? String,
      let baseURL = URL(string: cableURLString) else {
    self.connectionStatus = .error("Invalid WebSocket URL configuration")
    return
}
```

---

### 3. **Mismatched Data Model Types (String vs Int)**

**Severity**: 🔴 CRITICAL

**Location**:
- `Models.swift` - `Item.id: Int`, `Item.list_id: Int`
- `APIDTOs.swift` - `TaskDTO.id: String`, `TaskDTO.list_id: String`

**Problem**:
The API returns task IDs as **Integers** but some models expect **Strings**:

```swift
// Rails API Response (from your audit)
{
  "id": 1,              // Integer
  "list_id": 5,         // Integer
  "title": "Task name"
}

// APIDTOs.swift (WRONG)
struct TaskDTO: Codable {
    let id: String      // ❌ Type mismatch
    let list_id: String // ❌ Type mismatch
}

// Models.swift (CORRECT)
struct Item: Codable {
    let id: Int         // ✅ Matches API
    let list_id: Int    // ✅ Matches API
}
```

**Impact**:
- JSON decoding will fail completely
- Tasks cannot be loaded from API
- App will crash or show empty lists

**Fix Required**:
Update `APIDTOs.swift`:
```swift
struct TaskDTO: Codable, Identifiable {
    let id: Int           // Changed from String
    let list_id: Int      // Changed from String
    let title: String
    let notes: String?
    let visibility: String
    let completed_at: String?
    let updated_at: String?
    let deleted_at: String?
}
```

---

### 4. **Mismatched List Model Types**

**Severity**: 🔴 CRITICAL

**Location**: `focusmate/Focusmate/Core/Models/Models.swift:55`

**Problem**:
```swift
struct ListDTO: Codable, Identifiable {
  let id: String        // ❌ Rails returns Int
  let title: String
  let visibility: String
}
```

Based on your Rails API audit, the lists endpoint returns:
```json
{
  "id": 1,              // Integer, not String
  "title": "My List",
  "visibility": "private"
}
```

**Impact**:
- List fetching will fail with JSON decoding errors
- Users cannot see their lists
- App will be unusable

**Fix Required**:
```swift
struct ListDTO: Codable, Identifiable {
  let id: Int           // Changed from String
  let title: String
  let visibility: String
  let updated_at: String?
  let deleted_at: String?
}
```

---

### 5. **Base URL Configuration Mismatch**

**Severity**: 🔴 CRITICAL

**Location**: Multiple files

**Problem**:
The app has THREE different sources for the base URL:

```swift
// 1. Debug-Info.plist (used by old APIClient via Endpoints.swift)
API_BASE_URL = https://untampered-jong-harshly.ngrok-free.dev/api/v1

// 2. Debug.xcconfig (NOT being read by app at runtime)
API_BASE_URL = http://localhost:3000/api/v1

// 3. APIEndpoints.swift (used by NewAPIClient)
static let base: URL = {
    if let stagingURL = ProcessInfo.processInfo.environment["STAGING_API_URL"] {
        return URL(string: stagingURL)!
    } else {
        return URL(string: "http://localhost:3000")!  // Missing /api/v1
    }
}()
```

**Issues**:
- `.xcconfig` files don't set environment variables at runtime
- Info.plist has ngrok URL (temporary)
- NewAPIClient fallback missing `/api/v1` path prefix
- Different clients hit different URLs

**Impact**:
- Some API calls succeed, others fail
- Inconsistent behavior
- Hard to switch between dev/staging/production

**Fix Required**:
1. Consolidate to ONE URL source (Info.plist is best)
2. Update Debug-Info.plist to use localhost for development
3. Ensure all API clients read from the same source
4. Add `/api/v1` to all base URLs

---

### 6. **Missing Visibility Field in Item Model**

**Severity**: 🔴 CRITICAL

**Location**: `focusmate/Focusmate/Core/Models/Models.swift:183`

**Problem**:
```swift
struct Item: Codable {
  // ... lots of fields ...
  let is_visible: Bool   // Field name in code

  enum CodingKeys: String, CodingKey {
    // ...
    case is_visible = "visibility"  // Maps to "visibility" in JSON
  }
}
```

But the Rails API returns `visibility` as a **String** ("private", "shared", "public"), not a Boolean:

```json
{
  "visibility": "private"  // String, not Boolean
}
```

**Impact**:
- JSON decoding fails for all tasks
- App cannot load any tasks
- Complete failure of task features

**Fix Required**:
```swift
struct Item: Codable {
  let visibility: String  // Changed from is_visible: Bool

  // Add computed property for convenience
  var isVisible: Bool {
    return visibility != "private"
  }

  enum CodingKeys: String, CodingKey {
    case visibility  // Remove mapping
    // ...
  }
}
```

---

### 7. **Missing `escalation.level` Type Mismatch**

**Severity**: 🔴 CRITICAL

**Location**: `focusmate/Focusmate/Core/Models/Models.swift:193`

**Problem**:
```swift
struct Escalation: Codable {
  let level: String  // Expects "low", "medium", "high"
  // ...
}
```

But Rails API returns `level` as an **Integer**:
```json
{
  "escalation": {
    "level": 2,  // Integer (1, 2, 3, 4)
    "notification_count": 5
  }
}
```

**Impact**:
- Tasks with escalations fail to decode
- Overdue task features break
- Blocking tasks view crashes

**Fix Required**:
```swift
struct Escalation: Codable {
  let level: Int  // Changed from String
  let notification_count: Int
  let blocking_app: Bool
  let coaches_notified: Bool
  let became_overdue_at: String?
  let last_notification_at: String?

  // Add computed property for display
  var levelString: String {
    switch level {
    case 1: return "low"
    case 2: return "medium"
    case 3: return "high"
    case 4: return "critical"
    default: return "unknown"
    }
  }
}
```

---

### 8. **AuthService Endpoint Path Mismatch**

**Severity**: 🔴 CRITICAL

**Location**: `focusmate/Focusmate/Core/Services/AuthService.swift:14`

**Problem**:
```swift
func signIn(email: String, password: String) async throws -> SignInResponse {
    let request = SignInRequest(authentication: AuthCredentials(email: email, password: password))
    return try await self.apiClient.request("POST", "auth/sign_in", body: request)
    //                                                  ^^^^^^^^^^^
    // Missing /api/v1 prefix - relies on base URL having it
}
```

But `Endpoints.base` from Info.plist includes the full path:
```
API_BASE_URL = https://...ngrok.../api/v1
```

And `APIEndpoints.swift` fallback doesn't:
```swift
return URL(string: "http://localhost:3000")!  // Missing /api/v1
```

**Impact**:
- Auth calls might hit `/auth/sign_in` instead of `/api/v1/auth/sign_in`
- 404 Not Found errors
- Cannot sign in or sign up

**Fix Required**:
Ensure base URL consistency:
```swift
// Option 1: Base URL includes /api/v1, paths don't
Base: http://localhost:3000/api/v1
Path: auth/sign_in
Full: http://localhost:3000/api/v1/auth/sign_in ✅

// Option 2: Base URL is domain only, paths include /api/v1
Base: http://localhost:3000
Path: /api/v1/auth/sign_in
Full: http://localhost:3000/api/v1/auth/sign_in ✅
```

Pick ONE approach and make it consistent everywhere.

---

## 🟡 MAJOR ISSUES (Should Fix)

### 9. **No Environment Switching Mechanism**

**Severity**: 🟡 MAJOR

**Problem**: The app hardcodes URLs in Info.plist with no easy way to switch between:
- Local development (localhost:3000)
- Staging (ngrok or test server)
- Production (final domain)

**Fix Required**:
Implement build configuration schemes or environment variable reading.

---

### 10. **Incomplete Error Response Handling**

**Severity**: 🟡 MAJOR

**Location**: `InternalNetworking.swift:140`

**Problem**:
```swift
private func parseErrorResponse(data: Data, statusCode: Int) -> ErrorResponse? {
    // Falls back to generic errors
    // Doesn't handle all Rails error formats
}
```

Rails returns various error formats:
```json
// Validation errors
{"errors": {"email": ["can't be blank"]}}

// Generic errors
{"error": "Unauthorized"}

// Structured errors
{"code": "INVALID_TOKEN", "message": "Token expired"}
```

**Impact**: Users see generic error messages instead of specific validation feedback.

**Fix Required**: Implement comprehensive error parsing for all Rails formats.

---

### 11. **ItemService Endpoint Fallback Cascade is Fragile**

**Severity**: 🟡 MAJOR

**Location**: `focusmate/Focusmate/Core/Services/ItemService.swift` (mentioned in Task exploration)

**Problem**: ItemService tries 6 different endpoints in sequence when fetching items:
```swift
1. GET /lists/:listId/tasks
2. GET /tasks?list_id=:id (if 404)
3. GET /items?list_id=:id (if 404)
4. GET /tasks/all_tasks?list_id=:id (if 404)
5. GET /tasks/all_tasks (if 404)
6. GET /tasks (if 404)
```

**Impact**:
- Slow performance (multiple failed requests)
- Confusing error messages
- Indicates API contract is not finalized

**Fix Required**:
- Confirm the correct endpoint with backend
- Remove fallback cascade
- Use ONE canonical endpoint

---

### 12. **No JWT Expiration Handling**

**Severity**: 🟡 MAJOR

**Location**: `AuthStore.swift`, `AuthSession.swift`

**Problem**:
- JWT tokens expire after 1 hour (from Rails audit)
- App has no automatic refresh mechanism
- App doesn't decode JWT to check expiration
- Users will see 401 errors after 1 hour and must manually sign in again

**Impact**: Poor user experience, frequent re-authentication required.

**Fix Required**:
1. Decode JWT to read expiration
2. Implement automatic token refresh before expiration
3. Handle 401 gracefully with re-auth prompt

---

### 13. **Device Registration API Call Structure Unknown**

**Severity**: 🟡 MAJOR

**Location**: `focusmate/Focusmate/Core/Services/DeviceService.swift`

**Problem**:
```swift
struct DeviceInfo: Codable {
  let platform: String = "ios"
  let version: String
  let model: String
  let systemVersion: String
  let appVersion: String
  let pushToken: String?

  enum CodingKeys: String, CodingKey {
    // ...
    case pushToken = "apns_token"  // Is this correct?
  }
}
```

The device registration endpoint format is unclear:
- Does Rails expect `{device: {...}}` wrapper?
- Is the field name `apns_token` or `push_token`?
- What's the exact endpoint path?

**Impact**: Push notifications may fail to register.

**Fix Required**: Verify exact API contract with backend and update accordingly.

---

## 🟢 MINOR ISSUES (Improvements)

### 14. **Duplicate Empty Response Types**

**Severity**: 🟢 MINOR

**Location**: Multiple files

**Problem**:
```swift
// AuthService.swift
struct EmptyResponse: Codable {}

// Models.swift
struct EmptyAPIResponse: Decodable {}

// APIDTOs.swift
struct Empty: Decodable {}
```

Three different types for the same purpose.

**Fix Required**: Consolidate to one shared type.

---

### 15. **Inconsistent Coding Key Naming**

**Severity**: 🟢 MINOR

**Problem**: Some models use manual CodingKeys, others rely on property names:

```swift
// Some use explicit mapping
case isVisible = "is_visible"

// Others assume snake_case auto-conversion
case listId = "list_id"

// Some use exact property names matching JSON
case due_at
```

**Fix Required**: Pick ONE strategy (prefer explicit CodingKeys for clarity).

---

### 16. **Missing API Documentation in Code**

**Severity**: 🟢 MINOR

**Problem**: Service methods lack documentation about:
- Expected API response format
- Error codes
- Required permissions

**Fix Required**: Add docstrings to all service methods.

---

## 📊 Data Model Comparison: Swift vs Rails API

### User Model
| Field | Swift (UserDTO) | Rails API | Status |
|-------|----------------|-----------|---------|
| id | Int | Integer | ✅ Match |
| email | String | String | ✅ Match |
| name | String | String | ✅ Match |
| role | String | String | ✅ Match |
| timezone | String? | String (nullable) | ✅ Match |

### List Model
| Field | Swift (ListDTO) | Rails API | Status |
|-------|-----------------|-----------|---------|
| id | **String** | **Integer** | ❌ **MISMATCH** |
| title | String | String | ✅ Match |
| visibility | String | String | ✅ Match |
| updated_at | String? | Timestamp | ✅ Match |
| deleted_at | String? | Timestamp | ✅ Match |

### Task/Item Model
| Field | Swift (Item) | Rails API | Status |
|-------|--------------|-----------|---------|
| id | Int | Integer | ✅ Match |
| list_id | Int | Integer | ✅ Match |
| title | String | String | ✅ Match |
| description/notes | String? | String? | ✅ Match |
| visibility | **is_visible: Bool** | **"private"\|"shared"** | ❌ **MISMATCH** |
| due_at | String? | Timestamp | ✅ Match |
| completed_at | String? | Timestamp | ✅ Match |
| priority | Int | Integer (0-3) | ✅ Match |
| escalation.level | **String** | **Integer** | ❌ **MISMATCH** |

### TaskDTO Model (APIDTOs.swift)
| Field | Swift (TaskDTO) | Rails API | Status |
|-------|-----------------|-----------|---------|
| id | **String** | **Integer** | ❌ **MISMATCH** |
| list_id | **String** | **Integer** | ❌ **MISMATCH** |
| title | String | String | ✅ Match |
| notes | String? | String? | ✅ Match |
| visibility | String | String | ✅ Match |

---

## 🔧 Configuration Audit

### Current Configuration State

**Debug-Info.plist**:
```xml
<key>API_BASE_URL</key>
<string>https://untampered-jong-harshly.ngrok-free.dev/api/v1</string>
<key>CABLE_URL</key>
<string>wss://untampered-jong-harshly.ngrok-free.dev/cable</string>
```
❌ **Issue**: Points to temporary ngrok URL

**Debug.xcconfig**:
```
API_BASE_URL = http://localhost:3000/api/v1
CABLE_URL = ws://localhost:3000/cable
```
✅ **Correct** for local development, but NOT being used by app at runtime

**Endpoints.swift**:
```swift
static let base: URL = {
    guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
          let url = URL(string: urlString)
    else {
        fatalError("API_BASE_URL not found in Info.plist")
    }
    return url
}()
```
✅ Reads from Info.plist (good), but Info.plist has wrong URL

**APIEndpoints.swift** (different file!):
```swift
static let base: URL = {
    if let stagingURL = ProcessInfo.processInfo.environment["STAGING_API_URL"] {
        return URL(string: stagingURL)!
    } else {
        return URL(string: "http://localhost:3000")!  // ❌ Missing /api/v1
    }
}()
```

**WebSocketManager.swift**:
```swift
guard let baseURL = URL(string: "wss://untampered-jong-harshly.ngrok-free.dev/cable") else {
```
❌ **Hardcoded** ngrok URL

---

## 🎯 Priority Fix Checklist

### Immediate (Before any testing):

- [ ] **Fix #3**: Change `TaskDTO.id` and `TaskDTO.list_id` from String to Int
- [ ] **Fix #4**: Change `ListDTO.id` from String to Int
- [ ] **Fix #6**: Change `Item.is_visible: Bool` to `visibility: String`
- [ ] **Fix #7**: Change `Escalation.level: String` to `level: Int`
- [ ] **Fix #2**: Replace hardcoded WebSocket URL with configuration
- [ ] **Fix #5**: Update Debug-Info.plist to use localhost:3000
- [ ] **Fix #1**: Audit which API client each service uses and standardize

### High Priority (Before production):

- [ ] **Fix #8**: Verify and fix endpoint path construction
- [ ] **Fix #11**: Remove ItemService fallback cascade, use canonical endpoint
- [ ] **Fix #12**: Implement JWT expiration handling and refresh
- [ ] **Fix #9**: Implement environment configuration switching
- [ ] **Fix #13**: Verify device registration API contract

### Medium Priority (Nice to have):

- [ ] **Fix #10**: Improve error response parsing
- [ ] **Fix #14-16**: Clean up code quality issues

---

## 🧪 Testing Recommendations

### 1. Unit Tests Needed
- [ ] Test JSON decoding for all models with sample Rails API responses
- [ ] Test API client URL construction
- [ ] Test authentication token handling
- [ ] Test error response parsing

### 2. Integration Tests Needed
- [ ] Sign up flow end-to-end
- [ ] Sign in flow end-to-end
- [ ] List CRUD operations
- [ ] Task CRUD operations
- [ ] WebSocket connection and message handling
- [ ] Push notification registration

### 3. Manual Testing Checklist
- [ ] Start Rails server: `bundle exec rails server`
- [ ] Update Debug-Info.plist to localhost
- [ ] Build and run app in simulator
- [ ] Sign up new user
- [ ] Sign in existing user
- [ ] Create list
- [ ] Create task in list
- [ ] Complete task
- [ ] Monitor Rails logs for errors

---

## 📁 Files Requiring Changes

### Critical Fixes:
1. `/focusmate/Focusmate/Core/API/APIDTOs.swift` - Fix type mismatches
2. `/focusmate/Focusmate/Core/Models/Models.swift` - Fix type mismatches
3. `/focusmate/Focusmate/Core/Services/WebSocketManager.swift` - Fix hardcoded URL
4. `/focusmate/Debug-Info.plist` - Update to localhost
5. `/focusmate/Focusmate/Core/API/APIEndpoints.swift` - Add /api/v1 to fallback

### Major Refactoring Needed:
6. Consider removing one of: `APIClient.swift` OR `NewAPIClient.swift`
7. Update all services to use the chosen client consistently

---

## 🚀 Getting Started (After Fixes)

Once the critical issues above are fixed:

1. **Start Rails Server**:
   ```bash
   cd /Users/monsoudzanaty/Documents/focusmate-api
   bundle exec rails server
   ```

2. **Verify Server**:
   ```bash
   curl http://localhost:3000/health
   # Should return: {"status":"ok"}
   ```

3. **Open iOS App**:
   ```bash
   cd /Users/monsoudzanaty/Documents/focusmate
   open focusmate.xcodeproj
   ```

4. **Build and Run** in simulator (⌘R)

5. **Test Authentication**:
   - Try signing up
   - Try signing in
   - Check Rails logs for requests

---

## 📝 Summary

The iOS app has solid architecture with good separation of concerns, but **the API integration layer has critical type mismatches and configuration issues** that will prevent it from working with the Rails backend.

**Most Critical**:
- Type mismatches (String vs Int IDs)
- Hardcoded temporary URLs
- Duplicate API client implementations

**Estimated Fix Time**: 4-6 hours for critical issues, 1-2 days for all major issues.

Once fixed, the app should work well with the Rails API. The underlying architecture (SwiftData persistence, WebSocket support, error handling) is well-designed.

---

**Next Steps**: Start with the "Immediate" checklist above, then test authentication flow before moving to other features.
