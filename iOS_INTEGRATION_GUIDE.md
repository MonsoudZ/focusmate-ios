# iOS Integration Guide - Focusmate App

## 🔍 Issue Analysis

**The Rails API is working perfectly!** ✅ The issue is in the iOS app's client-side logic.

### What's Happening:
- ✅ **Rails API is working** - Login returns `200 OK` with JWT token
- ✅ **Authentication is successful** - User is found and validated  
- ❌ **iOS app isn't navigating** - It's not handling the successful login response

## 🚨 Current iOS App Issues

The iOS app has these problems:

1. **Not parsing the response** - App doesn't extract the JWT token properly
2. **Not storing the token** - Token gets lost between screens
3. **Not navigating** - App stays on login screen after successful auth
4. **Not making API calls** - App doesn't fetch user data after login

## 📋 What the iOS App Should Do

After receiving a successful login response from Rails:

```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJqdGkiOiIwYjYyMDI1NC1lNzkzLTRmMGUtODA3ZC1hMDIyZDdlMzhlOTUiLCJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzYwNDYxNDY4LCJleHAiOjE3NjA1NDc4Njh9.8Pemk8Y2K0jtO9jETB29Qf2_FDG3zPygp8qEDWsvWzY",
  "user": {
    "id": 1,
    "email": "test@example.com",
    "name": "Test User"
  }
}
```

The iOS app needs to:

1. **Extract the JWT token** from the response
2. **Store the token securely** (Keychain recommended)
3. **Navigate to the main app screen** (lists view)
4. **Make API calls** to `GET /api/v1/lists` to fetch user's lists

## 🔧 iOS Implementation Fixes

### 1. Fix Response Parsing

**Current Issue**: The `SignInResp` struct might not match the Rails response format.

**Fix**: Update the response struct to match exactly:

```swift
struct SignInResp: Decodable {
    let message: String
    let token: String
    let user: UserDTO
}
```

### 2. Fix Token Storage

**Current Issue**: Token might not be stored properly in Keychain.

**Fix**: Ensure token is stored immediately after successful login:

```swift
func signIn(email: String, password: String) async {
    isLoading = true
    error = nil
    
    do {
        let resp: SignInResp = try await api.request("POST", "auth/sign_in", body: SignInReq(email: email, password: password))
        
        // Store token immediately
        jwt = resp.token
        KeychainStore.shared.save(token: resp.token)
        currentUser = resp.user
        
        print("✅ Login successful - Token stored: \(resp.token)")
        
    } catch {
        print("❌ Login failed: \(error)")
        self.error = "\(error)"
        jwt = nil
        KeychainStore.shared.clear()
    }
    
    isLoading = false
}
```

### 3. Fix Navigation Logic

**Current Issue**: `RootView` might not be reacting to JWT changes.

**Fix**: Ensure `RootView` properly observes authentication state:

```swift
struct RootView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        Group {
            if state.auth.jwt == nil {
                SignInView()
            } else {
                ListsView()
                    .task {
                        await state.auth.loadProfile()
                    }
            }
        }
        .onAppear {
            print("🔄 RootView: jwt=\(state.auth.jwt != nil ? "SET" : "NIL")")
        }
    }
}
```

### 4. Fix API Calls After Login

**Current Issue**: App might not be making authenticated API calls.

**Fix**: Ensure API client uses the stored token:

```swift
final class APIClient {
    private let session: URLSession = .shared
    private let tokenProvider: () -> String?

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
    }

    func request<T: Decodable, B: Encodable>(_ method: String, _ path: String, body: B? = nil) async throws -> T {
        var req = URLRequest(url: Endpoints.path(path))
        req.httpMethod = method
        
        // Add JWT token to headers
        if let jwt = tokenProvider() {
            req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
            print("🔑 Using JWT token: \(jwt.prefix(20))...")
        }
        
        // ... rest of implementation
    }
}
```

## 🧪 Testing Steps

1. **Check Rails Logs**: Should show `200 OK` for login
2. **Check iOS Console**: Should show "Login successful - Token stored"
3. **Check Navigation**: Should automatically navigate to Lists screen
4. **Check API Calls**: Should make authenticated calls to `/api/v1/lists`

## 🐛 Debug Checklist

- [ ] Is the JWT token being extracted from the response?
- [ ] Is the token being stored in Keychain?
- [ ] Is the `AuthStore.jwt` property being set?
- [ ] Is the `RootView` observing the JWT change?
- [ ] Is the navigation logic working?
- [ ] Are subsequent API calls using the JWT token?

## 📱 Expected User Flow

1. User enters email/password
2. App calls Rails `/api/v1/auth/sign_in`
3. Rails returns JWT token + user data
4. App stores token in Keychain
5. App sets `AuthStore.jwt` property
6. `RootView` detects JWT change
7. App navigates to `ListsView`
8. App calls `/api/v1/lists` with JWT token
9. App displays user's lists

## 🚀 The Rails API is Working Perfectly!

The issue is **100% in the iOS app's client-side logic**. The Rails API is:
- ✅ Returning correct JWT tokens
- ✅ Validating users properly  
- ✅ Responding with proper JSON format
- ✅ Ready to serve authenticated requests

**Focus on fixing the iOS app's navigation and token handling!** 🎯
