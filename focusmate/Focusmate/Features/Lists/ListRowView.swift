import SwiftUI

struct ListRowView: View {
    let list: ListDTO

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(list.name)
                .font(DesignSystem.Typography.bodyEmphasized)

            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .listAccessibility(title: list.name, tasksCount: 0)
    }
}
