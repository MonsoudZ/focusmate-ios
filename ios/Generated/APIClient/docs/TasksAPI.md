# TasksAPI

All URIs are relative to *https://api.focusmate.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**listsListIdTasksGet**](TasksAPI.md#listslistidtasksget) | **GET** /lists/{listId}/tasks | Get tasks for specific list
[**listsListIdTasksPost**](TasksAPI.md#listslistidtaskspost) | **POST** /lists/{listId}/tasks | Create new task in list
[**tasksGet**](TasksAPI.md#tasksget) | **GET** /tasks | Get all tasks with delta sync
[**tasksIdCompletePost**](TasksAPI.md#tasksidcompletepost) | **POST** /tasks/{id}/complete | Complete task
[**tasksIdDelete**](TasksAPI.md#tasksiddelete) | **DELETE** /tasks/{id} | Delete task
[**tasksIdExplanationsPost**](TasksAPI.md#tasksidexplanationspost) | **POST** /tasks/{id}/explanations | Submit task explanation
[**tasksIdGet**](TasksAPI.md#tasksidget) | **GET** /tasks/{id} | Get task by ID
[**tasksIdPut**](TasksAPI.md#tasksidput) | **PUT** /tasks/{id} | Update task
[**tasksIdReassignPatch**](TasksAPI.md#tasksidreassignpatch) | **PATCH** /tasks/{id}/reassign | Reassign task


# **listsListIdTasksGet**
```swift
    open class func listsListIdTasksGet(listId: Int, since: Date? = nil, completion: @escaping (_ data: [Item]?, _ error: Error?) -> Void)
```

Get tasks for specific list

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let listId = 987 // Int | 
let since = Date() // Date | ISO8601 timestamp for delta sync (optional)

// Get tasks for specific list
TasksAPI.listsListIdTasksGet(listId: listId, since: since) { (response, error) in
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
 **listId** | **Int** |  | 
 **since** | **Date** | ISO8601 timestamp for delta sync | [optional] 

### Return type

[**[Item]**](Item.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listsListIdTasksPost**
```swift
    open class func listsListIdTasksPost(listId: Int, createItemRequest: CreateItemRequest, completion: @escaping (_ data: Item?, _ error: Error?) -> Void)
```

Create new task in list

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let listId = 987 // Int | 
let createItemRequest = CreateItemRequest(title: "title_example", description: "description_example", dueAt: Date(), isVisible: false) // CreateItemRequest | 

// Create new task in list
TasksAPI.listsListIdTasksPost(listId: listId, createItemRequest: createItemRequest) { (response, error) in
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
 **listId** | **Int** |  | 
 **createItemRequest** | [**CreateItemRequest**](CreateItemRequest.md) |  | 

### Return type

[**Item**](Item.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tasksGet**
```swift
    open class func tasksGet(since: Date? = nil, listId: Int? = nil, completion: @escaping (_ data: ItemsResponse?, _ error: Error?) -> Void)
```

Get all tasks with delta sync

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let since = Date() // Date | ISO8601 timestamp for delta sync (optional)
let listId = 987 // Int | Filter by list ID (optional)

// Get all tasks with delta sync
TasksAPI.tasksGet(since: since, listId: listId) { (response, error) in
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
 **listId** | **Int** | Filter by list ID | [optional] 

### Return type

[**ItemsResponse**](ItemsResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tasksIdCompletePost**
```swift
    open class func tasksIdCompletePost(id: Int, completeTaskRequest: CompleteTaskRequest, completion: @escaping (_ data: Item?, _ error: Error?) -> Void)
```

Complete task

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let completeTaskRequest = CompleteTaskRequest(notes: "notes_example") // CompleteTaskRequest | 

// Complete task
TasksAPI.tasksIdCompletePost(id: id, completeTaskRequest: completeTaskRequest) { (response, error) in
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
 **completeTaskRequest** | [**CompleteTaskRequest**](CompleteTaskRequest.md) |  | 

### Return type

[**Item**](Item.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tasksIdDelete**
```swift
    open class func tasksIdDelete(id: Int, completion: @escaping (_ data: Void?, _ error: Error?) -> Void)
```

Delete task

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 

// Delete task
TasksAPI.tasksIdDelete(id: id) { (response, error) in
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

# **tasksIdExplanationsPost**
```swift
    open class func tasksIdExplanationsPost(id: Int, explanationRequest: ExplanationRequest, completion: @escaping (_ data: TaskExplanation?, _ error: Error?) -> Void)
```

Submit task explanation

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let explanationRequest = ExplanationRequest(explanationType: "explanationType_example", notes: "notes_example") // ExplanationRequest | 

// Submit task explanation
TasksAPI.tasksIdExplanationsPost(id: id, explanationRequest: explanationRequest) { (response, error) in
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
 **explanationRequest** | [**ExplanationRequest**](ExplanationRequest.md) |  | 

### Return type

[**TaskExplanation**](TaskExplanation.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tasksIdGet**
```swift
    open class func tasksIdGet(id: Int, completion: @escaping (_ data: Item?, _ error: Error?) -> Void)
```

Get task by ID

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 

// Get task by ID
TasksAPI.tasksIdGet(id: id) { (response, error) in
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

[**Item**](Item.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tasksIdPut**
```swift
    open class func tasksIdPut(id: Int, updateItemRequest: UpdateItemRequest, completion: @escaping (_ data: Item?, _ error: Error?) -> Void)
```

Update task

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let updateItemRequest = UpdateItemRequest(title: "title_example", description: "description_example", completed: false, dueAt: Date(), isVisible: false) // UpdateItemRequest | 

// Update task
TasksAPI.tasksIdPut(id: id, updateItemRequest: updateItemRequest) { (response, error) in
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
 **updateItemRequest** | [**UpdateItemRequest**](UpdateItemRequest.md) |  | 

### Return type

[**Item**](Item.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **tasksIdReassignPatch**
```swift
    open class func tasksIdReassignPatch(id: Int, reassignTaskRequest: ReassignTaskRequest, completion: @escaping (_ data: Item?, _ error: Error?) -> Void)
```

Reassign task

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let id = 987 // Int | 
let reassignTaskRequest = ReassignTaskRequest(userId: 123) // ReassignTaskRequest | 

// Reassign task
TasksAPI.tasksIdReassignPatch(id: id, reassignTaskRequest: reassignTaskRequest) { (response, error) in
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
 **reassignTaskRequest** | [**ReassignTaskRequest**](ReassignTaskRequest.md) |  | 

### Return type

[**Item**](Item.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

