import SwiftUI

struct ListRowView: View {
    let list: ListDTO

    private var isSharedList: Bool {
        list.role != nil && list.role != "owner"
    }

    private var roleIcon: String {
        switch list.role {
        case "editor": return DS.Icon.edit
        case "viewer": return "eye"
        default: return DS.Icon.share
        }
    }

    private var roleColor: Color {
        switch list.role {
        case "editor": return DS.Colors.accent
        case "viewer": return .gray
        default: return DS.Colors.accent
        }
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Color indicator — capsule variant
            ColorBar(color: list.listColor)

            // List info
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(list.name)
                        .font(DS.Typography.bodyMedium)

                    if isSharedList {
                        Image(systemName: roleIcon)
                            .font(DS.Typography.caption)
                            .foregroundStyle(roleColor)
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    if let count = list.tasks_count {
                        Text(count == 1 ? "1 task" : "\(count) tasks")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isSharedList {
                        Text("•")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Text(list.role?.capitalized ?? "Shared")
                            .font(DS.Typography.caption)
                            .foregroundStyle(roleColor)
                    } else if let description = list.description, !description.isEmpty {
                        Text("•")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Text(description)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Image(systemName: DS.Icon.chevronRight)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .card()
    }
}
