# ListsAPI

All URIs are relative to *https://api.focusmate.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listsGet**](ListsAPI.md#listsget) | **GET** /lists | Get all lists
[**listsIdDelete**](ListsAPI.md#listsiddelete) | **DELETE** /lists/{id} | Delete list
[**listsIdGet**](ListsAPI.md#listsidget) | **GET** /lists/{id} | Get list by ID
[**listsIdPut**](ListsAPI.md#listsidput) | **PUT** /lists/{id} | Update list
[**listsIdSharePost**](ListsAPI.md#listsidsharepost) | **POST** /lists/{id}/share | Share list with user
[**listsIdSharesGet**](ListsAPI.md#listsidsharesget) | **GET** /lists/{id}/shares | Get list shares
[**listsIdSharesShareIdDelete**](ListsAPI.md#listsidsharesshareiddelete) | **DELETE** /lists/{id}/shares/{shareId} | Remove list share
[**listsPost**](ListsAPI.md#listspost) | **POST** /lists | Create new list


# **listsGet**
```swift
    open class func listsGet(since: Date? = nil, completion: @escaping (_ data: ListsResponse?, _ error: Error?) -> Void)
```

Get all lists

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let since = Date() // Date | ISO8601 timestamp for delta sync (optional)

// Get all lists
ListsAPI.listsGet(since: since) { (response, error) in
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

[**ListsResponse**](ListsResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsIdDelete**
```swift
    open class func listsIdDelete(id: Int, completion: @escaping (_ data: Void?, _ error: Error?) -> Void)
```

Delete list

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 

// Delete list
ListsAPI.listsIdDelete(id: id) { (response, error) in
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
 **id** | **Int** |  | 

### Return type

Void (empty response body)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsIdGet**
```swift
    open class func listsIdGet(id: Int, completion: @escaping (_ data: ListDTO?, _ error: Error?) -> Void)
```

Get list by ID

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 

// Get list by ID
ListsAPI.listsIdGet(id: id) { (response, error) in
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
 **id** | **Int** |  | 

### Return type

[**ListDTO**](ListDTO.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsIdPut**
```swift
    open class func listsIdPut(id: Int, updateListRequest: UpdateListRequest, completion: @escaping (_ data: ListDTO?, _ error: Error?) -> Void)
```

Update list

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let updateListRequest = UpdateListRequest(name: "name_example", description: "description_example") // UpdateListRequest | 

// Update list
ListsAPI.listsIdPut(id: id, updateListRequest: updateListRequest) { (response, error) in
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
 **id** | **Int** |  | 
 **updateListRequest** | [**UpdateListRequest**](UpdateListRequest.md) |  | 

### Return type

[**ListDTO**](ListDTO.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsIdSharePost**
```swift
    open class func listsIdSharePost(id: Int, shareListRequest: ShareListRequest, completion: @escaping (_ data: ShareListResponse?, _ error: Error?) -> Void)
```

Share list with user

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let shareListRequest = ShareListRequest(email: "email_example", role: "role_example") // ShareListRequest | 

// Share list with user
ListsAPI.listsIdSharePost(id: id, shareListRequest: shareListRequest) { (response, error) in
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
 **id** | **Int** |  | 
 **shareListRequest** | [**ShareListRequest**](ShareListRequest.md) |  | 

### Return type

[**ShareListResponse**](ShareListResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsIdSharesGet**
```swift
    open class func listsIdSharesGet(id: Int, completion: @escaping (_ data: [ListShare]?, _ error: Error?) -> Void)
```

Get list shares

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 

// Get list shares
ListsAPI.listsIdSharesGet(id: id) { (response, error) in
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
 **id** | **Int** |  | 

### Return type

[**[ListShare]**](ListShare.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsIdSharesShareIdDelete**
```swift
    open class func listsIdSharesShareIdDelete(id: Int, shareId: Int, completion: @escaping (_ data: Void?, _ error: Error?) -> Void)
```

Remove list share

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let shareId = 987 // Int | 

// Remove list share
ListsAPI.listsIdSharesShareIdDelete(id: id, shareId: shareId) { (response, error) in
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
 **id** | **Int** |  | 
 **shareId** | **Int** |  | 

### Return type

Void (empty response body)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsPost**
```swift
    open class func listsPost(createListRequest: CreateListRequest, completion: @escaping (_ data: ListDTO?, _ error: Error?) -> Void)
```

Create new list

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let createListRequest = CreateListRequest(name: "name_example", description: "description_example") // CreateListRequest | 

// Create new list
ListsAPI.listsPost(createListRequest: createListRequest) { (response, error) in
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
 **createListRequest** | [**CreateListRequest**](CreateListRequest.md) |  | 

### Return type

[**ListDTO**](ListDTO.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

