import SwiftData
import SwiftUI

struct SyncStatusView: View {
  @EnvironmentObject var appState: AppState
  @EnvironmentObject var swiftDataManager: SwiftDataManager
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: self.syncStatusIcon)
          .foregroundColor(self.syncStatusColor)

        Text(self.syncStatusText)
          .font(.caption)
          .foregroundColor(.secondary)

        Spacer()

        if self.swiftDataManager.syncStatus.syncInProgress {
          ProgressView()
            .scaleEffect(0.8)
        }

        Button(action: { self.isExpanded.toggle() }) {
          Image(systemName: self.isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      if self.isExpanded {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Last Sync:")
              .font(.caption2)
              .foregroundColor(.secondary)
            Spacer()
            Text(self.lastSyncText)
              .font(.caption2)
              .foregroundColor(.secondary)
          }

          HStack {
            Text("Pending Changes:")
              .font(.caption2)
              .foregroundColor(.secondary)
            Spacer()
            Text("\(self.swiftDataManager.syncStatus.pendingChanges)")
              .font(.caption2)
              .foregroundColor(.secondary)
          }

          if !self.swiftDataManager.syncStatus.isOnline {
            Button("Retry Sync") {
              Task {
                do {
                  try await self.appState.syncCoordinator.syncAll()
                  print("✅ SyncStatusView: Manual sync completed")
                } catch {
                  print("❌ SyncStatusView: Manual sync failed: \(error)")
                }
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
    if self.swiftDataManager.syncStatus.syncInProgress {
      return "arrow.clockwise"
    } else if self.swiftDataManager.syncStatus.isOnline {
      return "checkmark.circle.fill"
    } else {
      return "exclamationmark.triangle.fill"
    }
  }

  private var syncStatusColor: Color {
    if self.swiftDataManager.syncStatus.syncInProgress {
      return .blue
    } else if self.swiftDataManager.syncStatus.isOnline {
      return .green
    } else {
      return .orange
    }
  }

  private var syncStatusText: String {
    if self.swiftDataManager.syncStatus.syncInProgress {
      return "Syncing..."
    } else if self.swiftDataManager.syncStatus.isOnline {
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
    .environmentObject(AppState())
    .environmentObject(SwiftDataManager.shared)
}
