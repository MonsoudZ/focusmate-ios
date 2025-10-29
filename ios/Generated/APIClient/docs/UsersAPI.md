# UsersAPI

All URIs are relative to *https://api.focusmate.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**profileGet**](UsersAPI.md#profileget) | **GET** /profile | Get current user profile
[**usersGet**](UsersAPI.md#usersget) | **GET** /users | Get users with delta sync


# **profileGet**
```swift
    open class func profileGet(completion: @escaping (_ data: UserProfile?, _ error: Error?) -> Void)
```

Get current user profile

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient


// Get current user profile
UsersAPI.profileGet() { (response, error) in
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

[**UserProfile**](UserProfile.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **usersGet**
```swift
    open class func usersGet(since: Date? = nil, completion: @escaping (_ data: [UserDTO]?, _ error: Error?) -> Void)
```

Get users with delta sync

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let since = Date() // Date | ISO8601 timestamp for delta sync (optional)

// Get users with delta sync
UsersAPI.usersGet(since: since) { (response, error) in
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
 **since** | **Date** | ISO8601 timestamp for delta sync | [optional] 

### Return type

[**[UserDTO]**](UserDTO.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

