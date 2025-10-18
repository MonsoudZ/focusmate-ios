import SwiftUI
import SwiftData

struct SyncStatusView: View {
    @EnvironmentObject var swiftDataManager: SwiftDataManager
    @EnvironmentObject var deltaSyncService: DeltaSyncService
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: syncStatusIcon)
                    .foregroundColor(syncStatusColor)
                
                Text(syncStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if swiftDataManager.syncStatus.syncInProgress {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Last Sync:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastSyncText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Pending Changes:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(swiftDataManager.syncStatus.pendingChanges)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if !swiftDataManager.syncStatus.isOnline {
                        Button("Retry Sync") {
                            Task {
                                try await deltaSyncService.syncAll()
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var syncStatusIcon: String {
        if swiftDataManager.syncStatus.syncInProgress {
            return "arrow.clockwise"
        } else if swiftDataManager.syncStatus.isOnline {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var syncStatusColor: Color {
        if swiftDataManager.syncStatus.syncInProgress {
            return .blue
        } else if swiftDataManager.syncStatus.isOnline {
            return .green
        } else {
            return .orange
        }
    }
    
    private var syncStatusText: String {
        if swiftDataManager.syncStatus.syncInProgress {
            return "Syncing..."
        } else if swiftDataManager.syncStatus.isOnline {
            return "Synced"
        } else {
            return "Offline"
        }
    }
    
    private var lastSyncText: String {
        guard let lastSync = swiftDataManager.syncStatus.lastSuccessfulSync else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}

#Preview {
    SyncStatusView()
        .environmentObject(SwiftDataManager.shared)
        .environmentObject(DeltaSyncService(
            apiClient: APIClient(tokenProvider: { nil }),
            swiftDataManager: SwiftDataManager.shared
        ))
}
