import SwiftUI

struct ListRowView: View {
    let list: ListDTO

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(list.listColor)
                .frame(width: 4, height: 40)
            
            // List info
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let count = list.tasks_count {
                        Text(count == 1 ? "1 task" : "\(count) tasks")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    if let description = list.description, !description.isEmpty {
                        Text("•")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(description)
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}
