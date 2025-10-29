import SwiftUI

struct ListRowView: View {
  let list: ListDTO
  @State private var shares: [ListShare] = []
  @State private var isLoadingShares = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(self.list.title)
          .font(.headline)
        Spacer()
        Text("#\(self.list.id)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // ListDTO doesn't have description field
      // if let description = list.description {
      //   Text(description)
      //     .font(.subheadline)
      //     .foregroundStyle(.secondary)
      //     .lineLimit(2)
      // }

      HStack {
        // ListDTO doesn't have these fields - simplified for now
        Label("List", systemImage: "list.bullet")
          .font(.caption)
          .foregroundStyle(.secondary)

        // Shared with badge
        if !self.shares.isEmpty {
          Label("\(self.shares.count) shared", systemImage: "person.2")
            .font(.caption)
            .foregroundStyle(.blue)
        }

        Spacer()

        // ListDTO doesn't have createdAt field
        Text("Created")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 2)
    .task {
      await self.loadShares()
    }
  }

  private func loadShares() async {
    // Note: This would need a listService parameter to actually load shares
    // For now, we'll simulate with empty array
    self.shares = []
  }
}
