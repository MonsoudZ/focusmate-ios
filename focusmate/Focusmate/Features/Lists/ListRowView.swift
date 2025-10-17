import SwiftUI

struct ListRowView: View {
    let list: ListDTO
    @State private var shares: [ListShare] = []
    @State private var isLoadingShares = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(list.name)
                    .font(.headline)
                Spacer()
                Text("#\(list.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let description = list.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(list.tasksCount) tasks", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if list.overdueTasksCount > 0 {
                    Label("\(list.overdueTasksCount) overdue", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Label("\(list.role)", systemImage: "person.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Shared with badge
                if !shares.isEmpty {
                    Label("\(shares.count) shared", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                Spacer()
                
                Text(list.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .task {
            await loadShares()
        }
    }
    
    private func loadShares() async {
        // Note: This would need a listService parameter to actually load shares
        // For now, we'll simulate with empty array
        shares = []
    }
}


