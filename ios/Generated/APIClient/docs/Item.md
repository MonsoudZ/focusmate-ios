# Item

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**id** | **Int** |  | 
**listId** | **Int** |  | 
**title** | **String** |  | 
**description** | **String** |  | [optional] 
**dueAt** | **Date** |  | [optional] 
**completedAt** | **Date** |  | [optional] 
**priority** | **Int** |  | 
**canBeSnoozed** | **Bool** |  | 
**notificationIntervalMinutes** | **Int** |  | 
**requiresExplanationIfMissed** | **Bool** |  | 
**overdue** | **Bool** |  | 
**minutesOverdue** | **Int** |  | 
**requiresExplanation** | **Bool** |  | 
**isRecurring** | **Bool** |  | 
**recurrencePattern** | **String** |  | [optional] 
**recurrenceInterval** | **Int** |  | 
**recurrenceDays** | **[Int]** |  | [optional] 
**locationBased** | **Bool** |  | 
**locationName** | **String** |  | [optional] 
**locationLatitude** | **Double** |  | [optional] 
**locationLongitude** | **Double** |  | [optional] 
**locationRadiusMeters** | **Int** |  | 
**notifyOnArrival** | **Bool** |  | 
**notifyOnDeparture** | **Bool** |  | 
**missedReason** | **String** |  | [optional] 
**missedReasonSubmittedAt** | **Date** |  | [optional] 
**missedReasonReviewedAt** | **Date** |  | [optional] 
**creator** | [**UserDTO**](UserDTO.md) |  | 
**createdByCoach** | **Bool** |  | 
**canEdit** | **Bool** |  | 
**canDelete** | **Bool** |  | 
**canComplete** | **Bool** |  | 
**isVisible** | **Bool** |  | 
**escalation** | [**Escalation**](Escalation.md) |  | [optional] 
**hasSubtasks** | **Bool** |  | 
**subtasksCount** | **Int** |  | 
**subtasksCompletedCount** | **Int** |  | 
**subtaskCompletionPercentage** | **Int** |  | 
**createdAt** | **Date** |  | 
**updatedAt** | **Date** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


