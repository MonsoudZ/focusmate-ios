# Task Visibility Feature

This document describes the task visibility feature that allows users to control whether tasks are visible to other users who have access to the same list.

## Overview

The visibility feature provides a toggle in both task creation and editing forms that controls whether a task is visible to other users. This is useful for personal tasks that should remain private or for tasks that are still in draft status.

## Implementation

### 1. UI Components

#### CreateItemView
- **Location**: `Features/Items/CreateItemView.swift`
- **Toggle**: "Visible to others" toggle in the Visibility section
- **Default**: `true` (visible by default)
- **Help Text**: "When enabled, this task will be visible to other users who have access to this list"

#### EditItemView
- **Location**: `Features/Items/EditItemView.swift`
- **Toggle**: "Visible to others" toggle in the Visibility section
- **Initial Value**: Set to current task's visibility status
- **Help Text**: Same as create form

#### TaskActionSheet
- **Location**: `Features/Tasks/TaskActionSheet.swift`
- **Edit Button**: Orange "Edit Task" button in secondary actions
- **Permission Check**: Disabled if `item.can_edit` is false
- **Icon**: Pencil icon

### 2. API Integration

#### CreateItemRequest
```swift
struct CreateItemRequest: Codable {
    let name: String
    let description: String?
    let dueDate: Date?
    let isVisible: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, description
        case dueDate = "due_at"
        case isVisible = "is_visible"
    }
}
```

#### UpdateItemRequest
```swift
struct UpdateItemRequest: Codable {
    let name: String?
    let description: String?
    let completed: Bool?
    let dueDate: Date?
    let isVisible: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, description, completed
        case dueDate = "due_at"
        case isVisible = "is_visible"
    }
}
```

### 3. Service Methods

#### ItemService.createItem()
```swift
func createItem(
    listId: Int, 
    name: String, 
    description: String?, 
    dueDate: Date?, 
    isVisible: Bool = true
) async throws -> Item
```

#### ItemService.updateItem()
```swift
func updateItem(
    id: Int, 
    name: String?, 
    description: String?, 
    completed: Bool?, 
    dueDate: Date?, 
    isVisible: Bool? = nil
) async throws -> Item
```

#### ItemViewModel Methods
```swift
func createItem(
    listId: Int, 
    name: String, 
    description: String?, 
    dueDate: Date?, 
    isVisible: Bool = true
) async

func updateItem(
    id: Int, 
    name: String?, 
    description: String?, 
    completed: Bool?, 
    dueDate: Date?, 
    isVisible: Bool? = nil
) async
```

## API Request Format

### POST /lists/{listId}/tasks
```json
{
  "name": "Task Name",
  "description": "Task Description",
  "due_at": "2024-01-15T10:30:00Z",
  "is_visible": true
}
```

### PUT /tasks/{taskId}
```json
{
  "name": "Updated Task Name",
  "description": "Updated Description",
  "due_at": "2024-01-15T10:30:00Z",
  "is_visible": false
}
```

## Data Model

### Item Model
The `Item` model includes the `is_visible` field:
```swift
struct Item: Codable, Identifiable {
    // ... other fields
    let is_visible: Bool
    // ... other fields
}
```

### SwiftData Model
The SwiftData `Item` model also includes visibility:
```swift
@Model
final class Item {
    // ... other properties
    var isVisible: Bool
    // ... other properties
}
```

## User Experience

### Task Creation
1. User taps "+" to create a new task
2. Fills in task details (name, description, due date)
3. **Visibility Toggle**: "Visible to others" is ON by default
4. User can toggle OFF to make task private
5. Task is created with the specified visibility

### Task Editing
1. User taps on a task to open TaskActionSheet
2. Taps "Edit Task" button (if they have edit permissions)
3. EditItemView opens with current task details
4. **Visibility Toggle**: Shows current visibility status
5. User can change visibility and save

### Permission Handling
- Edit button is disabled if `item.can_edit` is false
- Only users with edit permissions can change task visibility
- Visibility changes are included in the update request

## Testing

### VisibilityTestView
A comprehensive test view is available to verify:
1. **CreateItemRequest JSON**: Ensures `is_visible` field is included
2. **UpdateItemRequest JSON**: Ensures `is_visible` field is included
3. **UI Components**: Verifies all visibility-related UI elements exist
4. **API Integration**: Confirms visibility parameter is sent to API

### Test Access
- Navigate to the "Visibility" tab in the app
- Run the visibility tests to verify implementation
- Check JSON output to ensure proper field inclusion

## Benefits

1. **Privacy Control**: Users can keep personal tasks private
2. **Draft Tasks**: Create tasks that aren't ready for others to see
3. **Flexible Workflow**: Toggle visibility as tasks evolve
4. **Permission Respect**: Only users with edit access can change visibility
5. **API Consistency**: Visibility is included in both create and update operations

## Future Enhancements

1. **Bulk Visibility**: Change visibility for multiple tasks at once
2. **Visibility History**: Track when visibility was changed
3. **Visibility Filters**: Filter tasks by visibility in list views
4. **Visibility Notifications**: Notify users when task visibility changes
5. **Visibility Analytics**: Track usage patterns of visibility feature

## Troubleshooting

### Common Issues

1. **Visibility Not Saving**: Check API endpoint supports `is_visible` parameter
2. **Edit Button Disabled**: Verify user has `can_edit` permission
3. **JSON Encoding Issues**: Ensure `CodingKeys` are properly configured
4. **UI Not Updating**: Check that `@State` variables are properly bound

### Debug Information

The system provides logging for visibility operations:
```
✅ ItemViewModel: Created item with visibility: true
✅ ItemViewModel: Updated item visibility to: false
```

## API Requirements

The backend API must support:
1. **POST /lists/{listId}/tasks**: Accept `is_visible` parameter
2. **PUT /tasks/{taskId}**: Accept `is_visible` parameter
3. **Response Format**: Include `is_visible` field in task responses
4. **Permission Check**: Verify user has edit permissions for visibility changes

This implementation provides a complete visibility control system that integrates seamlessly with the existing task management workflow.
