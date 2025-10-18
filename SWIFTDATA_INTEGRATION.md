# SwiftData Integration with Delta Sync

This document describes the SwiftData integration with delta sync capabilities that has been added to the Focusmate iOS app.

## Overview

The app now uses SwiftData for local data persistence with delta sync functionality that only fetches changes since the last sync using the `since=` parameter.

## Architecture

### Core Components

1. **SwiftDataModels.swift** - SwiftData model definitions
2. **SwiftDataManager.swift** - Core SwiftData management and sync status
3. **DeltaSyncService.swift** - Delta sync implementation with `since=` parameter
4. **SyncStatusView.swift** - UI component showing sync status
5. **SwiftDataTestView.swift** - Testing interface for verification

### Data Models

The following SwiftData models have been created:

- `User` - User information with relationships
- `List` - Task lists with owner and shared relationships
- `Item` - Individual tasks/items with full feature set
- `Escalation` - Task escalation information
- `CoachShare` - List sharing with coaches
- `SyncMetadata` - Sync timestamp tracking
- `SyncStatus` - Current sync status

### Delta Sync Implementation

The delta sync system works by:

1. **Tracking Last Sync Times**: Each entity type has a `lastSyncTimestamp` stored in `SyncMetadata`
2. **Using `since=` Parameter**: API calls include `since=ISO8601_TIMESTAMP` to only fetch changes
3. **Local-First Approach**: Data is loaded from local SwiftData storage first, then synced
4. **Conflict Resolution**: Server data takes precedence over local changes

### Key Features

#### 1. Offline-First Architecture
- Data is always available from local SwiftData storage
- Sync happens in the background
- Users can work offline and sync when connection is restored

#### 2. Delta Sync with `since=` Parameter
```swift
// Example API call with delta sync
let parameters = swiftDataManager.getDeltaSyncParameters(for: "items")
// Results in: ["since": "2024-01-15T10:30:00Z"]
let items: [Item] = try await apiClient.request("GET", "tasks", queryParameters: parameters)
```

#### 3. Sync Status Tracking
- Real-time sync status display
- Last successful sync time
- Pending changes count
- Online/offline status

#### 4. Relationship Management
- Proper SwiftData relationships between entities
- Cascade delete rules for data integrity
- Bidirectional relationships maintained

## Usage

### Basic Data Access

```swift
// Fetch items from local storage
let items = itemService.fetchItemsFromLocal(listId: listId)

// Sync specific list
try await itemService.syncItemsForList(listId: listId)

// Full sync
try await deltaSyncService.syncAll()
```

### View Integration

```swift
struct MyView: View {
    @EnvironmentObject var swiftDataManager: SwiftDataManager
    @EnvironmentObject var deltaSyncService: DeltaSyncService
    
    var body: some View {
        VStack {
            // Your content
            SyncStatusView() // Shows sync status
        }
    }
}
```

### Testing

The `SwiftDataTestView` provides a testing interface to verify:

1. **SwiftData Integration**: Creates test data and verifies relationships
2. **Delta Sync Parameters**: Tests the `since=` parameter generation
3. **Full Sync**: Tests the complete sync process

## API Integration

### Delta Sync Parameters

The system automatically adds `since=` parameters to API calls:

```swift
// For users
GET /users?since=2024-01-15T10:30:00Z

// For lists  
GET /lists?since=2024-01-15T10:30:00Z

// For items
GET /tasks?since=2024-01-15T10:30:00Z&list_id=123
```

### Expected API Response Format

The API should return only changed entities since the provided timestamp:

```json
[
  {
    "id": 123,
    "title": "Updated Task",
    "updated_at": "2024-01-15T11:00:00Z",
    // ... other fields
  }
]
```

## Configuration

### Model Container Setup

The SwiftData model container is configured in `FocusmateApp.swift`:

```swift
@main
struct FocusmateApp: App {
    @StateObject var swiftDataManager = SwiftDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(swiftDataManager.modelContainer)
        }
    }
}
```

### Service Dependencies

Services are initialized with proper dependencies:

```swift
let itemService = ItemService(
    apiClient: apiClient,
    swiftDataManager: swiftDataManager,
    deltaSyncService: deltaSyncService
)
```

## Benefits

1. **Performance**: Only syncs changed data, reducing bandwidth and time
2. **Offline Support**: Full functionality without internet connection
3. **Data Integrity**: Proper relationships and cascade rules
4. **User Experience**: Real-time sync status and smooth data loading
5. **Scalability**: Efficient sync for large datasets

## Testing

Use the built-in test interface to verify:

1. SwiftData model creation and relationships
2. Delta sync parameter generation
3. Full sync functionality
4. Data persistence and retrieval

## Future Enhancements

1. **Conflict Resolution**: Handle simultaneous edits
2. **Batch Operations**: Group multiple changes for efficiency
3. **Selective Sync**: Sync only specific entity types
4. **Background Sync**: Automatic sync when app becomes active
5. **Sync Analytics**: Track sync performance and issues

## Troubleshooting

### Common Issues

1. **Sync Failures**: Check network connectivity and API endpoints
2. **Data Not Appearing**: Verify SwiftData relationships are properly set
3. **Performance Issues**: Consider pagination for large datasets
4. **Memory Issues**: Monitor SwiftData context usage

### Debug Information

The system provides extensive logging:

```
🔄 DeltaSyncService: Starting item sync...
✅ DeltaSyncService: Item sync completed
✅ SwiftDataManager: Found 5 items in local storage
```

## Migration from DTOs

The existing DTO-based system continues to work alongside SwiftData:

- DTOs are used for API communication
- SwiftData models are used for local storage
- Automatic conversion between DTOs and SwiftData models
- Gradual migration path available

This integration provides a robust foundation for offline-first functionality with efficient delta sync capabilities.
