# AuthenticationAPI

All URIs are relative to *https://api.focusmate.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**authRefreshPost**](AuthenticationAPI.md#authrefreshpost) | **POST** /auth/refresh | Refresh authentication token
[**authSignInPost**](AuthenticationAPI.md#authsigninpost) | **POST** /auth/sign_in | Sign in user
[**authSignOutDelete**](AuthenticationAPI.md#authsignoutdelete) | **DELETE** /auth/sign_out | Sign out user
[**authSignUpPost**](AuthenticationAPI.md#authsignuppost) | **POST** /auth/sign_up | Sign up new user


# **authRefreshPost**
```swift
    open class func authRefreshPost(completion: @escaping (_ data: TokenRefreshResponse?, _ error: Error?) -> Void)
```

Refresh authentication token

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient


// Refresh authentication token
AuthenticationAPI.authRefreshPost() { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**TokenRefreshResponse**](TokenRefreshResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authSignInPost**
```swift
    open class func authSignInPost(signInRequest: SignInRequest, completion: @escaping (_ data: SignInResponse?, _ error: Error?) -> Void)
```

Sign in user

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let signInRequest = SignInRequest(email: "email_example", password: "password_example") // SignInRequest | 

// Sign in user
AuthenticationAPI.authSignInPost(signInRequest: signInRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **signInRequest** | [**SignInRequest**](SignInRequest.md) |  | 

### Return type

[**SignInResponse**](SignInResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authSignOutDelete**
```swift
    open class func authSignOutDelete(completion: @escaping (_ data: Void?, _ error: Error?) -> Void)
```

Sign out user

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient


// Sign out user
AuthenticationAPI.authSignOutDelete() { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

Void (empty response body)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **authSignUpPost**
```swift
    open class func authSignUpPost(signUpRequest: SignUpRequest, completion: @escaping (_ data: SignUpResponse?, _ error: Error?) -> Void)
```

Sign up new user

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let signUpRequest = SignUpRequest(email: "email_example", password: "password_example", passwordConfirmation: "passwordConfirmation_example", name: "name_example") // SignUpRequest | 

// Sign up new user
AuthenticationAPI.authSignUpPost(signUpRequest: signUpRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **signUpRequest** | [**SignUpRequest**](SignUpRequest.md) |  | 

### Return type

[**SignUpResponse**](SignUpResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

