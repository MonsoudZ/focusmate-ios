# EscalationsAPI

All URIs are relative to *https://api.focusmate.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**escalationsBlockingGet**](EscalationsAPI.md#escalationsblockingget) | **GET** /escalations/blocking | Get blocking tasks
[**escalationsIdResolvePatch**](EscalationsAPI.md#escalationsidresolvepatch) | **PATCH** /escalations/{id}/resolve | Resolve escalation
[**escalationsPost**](EscalationsAPI.md#escalationspost) | **POST** /escalations | Create escalation


# **escalationsBlockingGet**
```swift
    open class func escalationsBlockingGet(completion: @escaping (_ data: BlockingTasksResponse?, _ error: Error?) -> Void)
```

Get blocking tasks

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient


// Get blocking tasks
EscalationsAPI.escalationsBlockingGet() { (response, error) in
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

[**BlockingTasksResponse**](BlockingTasksResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **escalationsIdResolvePatch**
```swift
    open class func escalationsIdResolvePatch(id: Int, resolveEscalationRequest: ResolveEscalationRequest, completion: @escaping (_ data: EscalationResponse?, _ error: Error?) -> Void)
```

Resolve escalation

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let resolveEscalationRequest = ResolveEscalationRequest(resolutionNotes: "resolutionNotes_example") // ResolveEscalationRequest | 

// Resolve escalation
EscalationsAPI.escalationsIdResolvePatch(id: id, resolveEscalationRequest: resolveEscalationRequest) { (response, error) in
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
 **resolveEscalationRequest** | [**ResolveEscalationRequest**](ResolveEscalationRequest.md) |  | 

### Return type

[**EscalationResponse**](EscalationResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **escalationsPost**
```swift
    open class func escalationsPost(escalationRequest: EscalationRequest, completion: @escaping (_ data: EscalationResponse?, _ error: Error?) -> Void)
```

Create escalation

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let escalationRequest = EscalationRequest(itemId: 123, level: "level_example", reason: "reason_example") // EscalationRequest | 

// Create escalation
EscalationsAPI.escalationsPost(escalationRequest: escalationRequest) { (response, error) in
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
 **escalationRequest** | [**EscalationRequest**](EscalationRequest.md) |  | 

### Return type

[**EscalationResponse**](EscalationResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

