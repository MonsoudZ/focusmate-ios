import SwiftUI

struct ListRowView: View {
    let list: ListDTO

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Circle()
                .fill(list.listColor)
                .frame(width: 12, height: 12)
            
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
            
            Spacer()
            
            if let count = list.tasks_count, count > 0 {
                Text("\(count)")
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxs)
        .listAccessibility(title: list.name, tasksCount: list.tasks_count ?? 0)
    }
}
