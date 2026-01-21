import SwiftUI

struct ListRowView: View {
    let list: ListDTO
    
    private var isSharedList: Bool {
        list.role != nil && list.role != "owner"
    }
    
    private var roleIcon: String {
        switch list.role {
        case "editor": return "pencil"
        case "viewer": return "eye"
        default: return "person.2"
        }
    }
    
    private var roleColor: Color {
        switch list.role {
        case "editor": return DesignSystem.Colors.primary
        case "viewer": return .gray
        default: return .blue
        }
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(list.listColor)
                .frame(width: 4, height: 40)
            
            // List info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(list.name)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    // Shared indicator
                    if isSharedList {
                        Image(systemName: roleIcon)
                            .font(.caption)
                            .foregroundColor(roleColor)
                    }
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let count = list.tasks_count {
                        Text(count == 1 ? "1 task" : "\(count) tasks")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    // Role label for shared lists
                    if isSharedList {
                        Text("•")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(list.role?.capitalized ?? "Shared")
                            .font(DesignSystem.Typography.caption1)
                            .foregroundColor(roleColor)
                    } else if let description = list.description, !description.isEmpty {
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
