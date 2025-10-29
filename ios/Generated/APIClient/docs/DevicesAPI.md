# DevicesAPI

All URIs are relative to *https://api.focusmate.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**devicesPost**](DevicesAPI.md#devicespost) | **POST** /devices | Register device
[**devicesTokenPut**](DevicesAPI.md#devicestokenput) | **PUT** /devices/token | Update device token


# **devicesPost**
```swift
    open class func devicesPost(deviceRegistrationRequest: DeviceRegistrationRequest, completion: @escaping (_ data: DeviceRegistrationResponse?, _ error: Error?) -> Void)
```

Register device

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let deviceRegistrationRequest = DeviceRegistrationRequest(deviceId: "deviceId_example", platform: "platform_example", appVersion: "appVersion_example", pushToken: "pushToken_example") // DeviceRegistrationRequest | 

// Register device
DevicesAPI.devicesPost(deviceRegistrationRequest: deviceRegistrationRequest) { (response, error) in
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
 **deviceRegistrationRequest** | [**DeviceRegistrationRequest**](DeviceRegistrationRequest.md) |  | 

### Return type

[**DeviceRegistrationResponse**](DeviceRegistrationResponse.md)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **devicesTokenPut**
```swift
    open class func devicesTokenPut(updateDeviceTokenRequest: UpdateDeviceTokenRequest, completion: @escaping (_ data: Void?, _ error: Error?) -> Void)
```

Update device token

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import APIClient

let updateDeviceTokenRequest = UpdateDeviceTokenRequest(pushToken: "pushToken_example") // UpdateDeviceTokenRequest | 

// Update device token
DevicesAPI.devicesTokenPut(updateDeviceTokenRequest: updateDeviceTokenRequest) { (response, error) in
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
 **updateDeviceTokenRequest** | [**UpdateDeviceTokenRequest**](UpdateDeviceTokenRequest.md) |  | 

### Return type

Void (empty response body)

### Authorization

[BearerAuth](../README.md#BearerAuth)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

