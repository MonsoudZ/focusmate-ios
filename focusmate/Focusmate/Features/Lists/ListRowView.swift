import SwiftUI

struct ListRowView: View {
    let list: ListDTO

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
                
                Spacer()
                
                Text(list.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}


