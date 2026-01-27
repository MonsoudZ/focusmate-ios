# Disconnected Components Report
**Date:** January 25, 2026  
**Scope:** Components that are defined but not properly integrated

---

## 🔴 Critical Disconnections

### 1. AdvancedErrorHandler - Stub Methods Not Implemented
**File:** `focusmate/Focusmate/Core/Services/AdvancedErrorHandler.swift`  
**Lines:** 273-283

**Issue:** The `clearStoredCredentials()` and `navigateToSignIn()` methods are called from `handleUnauthorized()` but are just stub implementations that only log messages.

**Current Code:**
```swift
private func clearStoredCredentials() async {
    // Clear JWT token and user data
    // This would integrate with your AuthStore
    Logger.debug("🧹 AdvancedErrorHandler: Clearing stored credentials", category: .general)
}

private func navigateToSignIn() async {
    // Navigate to sign-in screen
    // This would integrate with your navigation system
    Logger.debug("🔐 AdvancedErrorHandler: Navigating to sign-in", category: .general)
}
```

**Impact:** When `handleUnauthorized()` is called, it doesn't actually clear credentials or navigate to sign-in. The actual work is done in `AuthStore.handleUnauthorizedEvent()`, but `AdvancedErrorHandler.handleUnauthorized()` is incomplete.

**Fix Required:**
```swift
private func clearStoredCredentials() async {
    // This should call AuthStore to clear session
    // Need to inject AuthStore or use a shared instance
    await AuthStore.shared?.clearLocalSession()
}

private func navigateToSignIn() async {
    // This should trigger navigation to sign-in
    // Could use NotificationCenter or a navigation coordinator
    NotificationCenter.default.post(name: .navigateToSignIn, object: nil)
}
```

**Status:** 🔴 **NOT CONNECTED** - Methods exist but don't perform their intended actions

---

### 2. SentryService.setUser() - Never Called on Sign In
**File:** `focusmate/Focusmate/Core/Services/SentryService.swift`  
**Method:** `setUser(id:email:name:)` (Line 101)

**Issue:** The method exists and is properly implemented, but it's never called when a user signs in or registers.

**Where it should be called:** In `AuthStore.setAuthenticatedSession()` after setting `currentUser`.

**Current Code (AuthStore.swift:262-267):**
```swift
private func setAuthenticatedSession(token: String, user: UserDTO) async {
    await authSession.set(token: token)
    jwt = token
    keychain.save(token: token)
    currentUser = user
    // ❌ Missing: SentryService.shared.setUser(id: user.id, email: user.email, name: user.name)
}
```

**Impact:** Sentry error tracking doesn't have user context, making it harder to debug user-specific issues.

**Fix Required:**
```swift
private func setAuthenticatedSession(token: String, user: UserDTO) async {
    await authSession.set(token: token)
    jwt = token
    keychain.save(token: token)
    currentUser = user
    
    // ✅ Add this:
    SentryService.shared.setUser(
        id: user.id,
        email: user.email ?? "",
        name: user.name ?? ""
    )
}
```

**Status:** 🔴 **NOT CONNECTED** - Method exists but is never invoked

---

### 3. SentryService.clearUser() - Never Called on Sign Out
**File:** `focusmate/Focusmate/Core/Services/SentryService.swift`  
**Method:** `clearUser()` (Line 115)

**Issue:** The method exists but is never called when a user signs out.

**Where it should be called:** In `AuthStore.clearLocalSession()` or `signOut()`.

**Current Code (AuthStore.swift:269-274):**
```swift
private func clearLocalSession() async {
    await authSession.clear()
    jwt = nil
    currentUser = nil
    keychain.clear()
    // ❌ Missing: SentryService.shared.clearUser()
}
```

**Impact:** Sentry continues to track errors with the previous user's context after sign-out.

**Fix Required:**
```swift
private func clearLocalSession() async {
    await authSession.clear()
    jwt = nil
    currentUser = nil
    keychain.clear()
    
    // ✅ Add this:
    SentryService.shared.clearUser()
}
```

**Status:** 🔴 **NOT CONNECTED** - Method exists but is never invoked

---

## 🟠 High Priority Disconnections

### 4. ScreenTimeService.selectDefaults() - Stub Implementation
**File:** `focusmate/Focusmate/Core/Services/ScreenTimeService.swift`  
**Line:** 103

**Issue:** The method exists but is a stub that doesn't actually do anything. The comment indicates it should set categories, but the actual implementation is missing.

**Current Code:**
```swift
func selectDefaults() {
    // This just sets categories - Social and Games
    // The actual category tokens need to come from FamilyActivityPicker
}
```

**Impact:** If this method is called (e.g., during onboarding), it won't actually configure default app blocking categories.

**Status:** 🟠 **INCOMPLETE** - Method exists but is a stub

**Note:** This might be intentional if the UI uses `FamilyActivityPicker` directly, but the method should either be removed or properly implemented.

---

### 5. AdvancedErrorHandler.handleUnauthorized() - Incomplete Integration
**File:** `focusmate/Focusmate/Core/Services/AdvancedErrorHandler.swift`  
**Line:** 254

**Issue:** While `handleUnauthorized()` is called from `ErrorHandler.handleUnauthorized()`, which is called from `AuthStore.handleUnauthorizedEvent()`, the `AdvancedErrorHandler`'s own methods (`clearStoredCredentials()` and `navigateToSignIn()`) don't actually work.

**Current Flow:**
1. `AuthStore.handleUnauthorizedEvent()` is called ✅
2. It calls `ErrorHandler.shared.handleUnauthorized()` ✅
3. Which calls `AdvancedErrorHandler.handleUnauthorized()` ✅
4. Which calls `clearStoredCredentials()` and `navigateToSignIn()` ❌ (stubs)

**Impact:** The error handler's unauthorized handling is partially functional (because `AuthStore` does the actual work), but the `AdvancedErrorHandler` methods are dead code.

**Status:** 🟠 **PARTIALLY CONNECTED** - Called but doesn't perform intended actions

---

## 🟡 Medium Priority - Potential Disconnections

### 6. TodayService - Only Used in One Place
**File:** `focusmate/Focusmate/Core/Services/TodayService.swift`

**Issue:** `TodayService` is only instantiated in `TodayView` and not stored in `AppState` like other services (`TaskService`, `ListService`, etc.).

**Current Usage:**
```swift
// In TodayView.swift
private var todayService: TodayService {
    TodayService(api: state.auth.api)
}
```

**Impact:** A new instance is created every time the computed property is accessed. This is inefficient and inconsistent with other services.

**Recommendation:** Add to `AppState`:
```swift
// In AppState.swift
private(set) lazy var todayService = TodayService(api: auth.api)
```

**Status:** 🟡 **INCONSISTENT** - Works but not following the same pattern as other services

---

### 7. EscalationService - Initialized But Not Fully Wired
**File:** `focusmate/Focusmate/Core/Services/EscalationService.swift`

**Status:** ✅ **CONNECTED** - Actually working correctly!

**Verification:**
- `taskBecameOverdue()` is called from `TaskRow.onAppear` ✅
- `taskCompleted()` is called from `TaskRow.completeTask()` ✅
- State is observed in `TodayView` ✅
- Initialized in `AppBootstrapper` ✅

**Note:** This is actually properly connected, just documenting for completeness.

---

## ✅ Properly Connected Components

### NotificationService.scheduleMorningBriefing()
**Status:** ✅ **CONNECTED** - Called from `TodayView` (line 456)

### EscalationService
**Status:** ✅ **CONNECTED** - Properly integrated with task completion/overdue logic

### NotificationService.scheduleEscalationNotification()
**Status:** ✅ **CONNECTED** - Called from `EscalationService`

---

## Summary

### Critical Issues (Must Fix)
1. ❌ `AdvancedErrorHandler.clearStoredCredentials()` - Stub, doesn't clear credentials
2. ❌ `AdvancedErrorHandler.navigateToSignIn()` - Stub, doesn't navigate
3. ❌ `SentryService.setUser()` - Never called on sign in
4. ❌ `SentryService.clearUser()` - Never called on sign out

### High Priority Issues
5. ⚠️ `ScreenTimeService.selectDefaults()` - Stub implementation

### Medium Priority Issues
6. ⚠️ `TodayService` - Not stored in AppState (inconsistent pattern)

---

## Recommended Actions

### Immediate (This Week)
1. **Connect Sentry user tracking:**
   - Call `SentryService.shared.setUser()` in `AuthStore.setAuthenticatedSession()`
   - Call `SentryService.shared.clearUser()` in `AuthStore.clearLocalSession()`

2. **Fix AdvancedErrorHandler stubs:**
   - Either implement `clearStoredCredentials()` and `navigateToSignIn()` properly
   - OR remove them if `AuthStore` handles unauthorized events directly

### Short Term (This Month)
3. **Implement or remove `ScreenTimeService.selectDefaults()`:**
   - If needed, implement properly with FamilyActivityPicker integration
   - If not needed, remove the method

4. **Refactor TodayService:**
   - Move to `AppState` for consistency with other services

---

## Testing Recommendations

After fixing these disconnections, test:

1. **Sentry Integration:**
   - Sign in → Check Sentry dashboard for user context
   - Sign out → Verify user context is cleared
   - Trigger an error → Verify it's associated with correct user

2. **Error Handling:**
   - Trigger unauthorized error → Verify credentials are cleared and navigation works

3. **Screen Time:**
   - If `selectDefaults()` is used, test that it actually sets defaults

---

## Notes

- Most services are properly connected and working
- The main issues are in error handling and observability (Sentry)
- The `AdvancedErrorHandler` appears to be a newer addition that wasn't fully integrated
- Consider whether `AdvancedErrorHandler` should handle unauthorized events or if `AuthStore` should continue to handle them directly
