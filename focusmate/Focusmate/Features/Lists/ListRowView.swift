import SwiftUI

struct ListRowView: View {
    let list: ListDTO

    private var isSharedList: Bool {
        list.role != nil && list.role != "owner"
    }

    private var hasMembers: Bool {
        guard let members = list.members else { return false }
        return members.count > 1
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Progress ring with color
            progressRing

            // List info
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(list.name)
                        .font(DS.Typography.bodyMedium)

                    if list.hasOverdue {
                        overdueBadge
                    }
                }

                HStack(spacing: DS.Spacing.sm) {
                    let count = list.parent_tasks_count ?? list.tasks_count
                    if let count {
                        if let completed = list.completed_tasks_count {
                            Text("\(completed)/\(count) done")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(count == 1 ? "1 task" : "\(count) tasks")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isSharedList {
                        Text("•")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Text(list.role?.capitalized ?? "Shared")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.accent)
                    }

                    if let tags = list.tags, !tags.isEmpty {
                        listTagsView(tags)
                    }
                }
            }

            Spacer()

            // Member avatars for shared lists
            if hasMembers {
                memberAvatars
            }

            Image(systemName: DS.Icon.chevronRight)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .card()
    }

    // MARK: - Color Indicator / Progress Ring

    @ViewBuilder
    private var progressRing: some View {
        if list.completed_tasks_count != nil {
            // Show progress ring when we have completion data
            ZStack {
                Circle()
                    .stroke(list.listColor.opacity(0.2), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: list.progress)
                    .stroke(list.listColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                if list.progress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(list.listColor)
                }
            }
            .frame(width: 32, height: 32)
        } else {
            // Fall back to color bar when no completion data
            ColorBar(color: list.listColor)
        }
    }

    // MARK: - Overdue Badge

    private var overdueBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text("\(list.overdue_tasks_count ?? 0)")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(DS.Colors.error)
        .clipShape(Capsule())
    }

    // MARK: - Tags View

    private func listTagsView(_ tags: [TagDTO]) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(tags.prefix(2)) { tag in
                Text(tag.name)
                    .font(DS.Typography.caption2.weight(.medium))
                    .foregroundStyle(tag.tagColor)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(tag.tagColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            if tags.count > 2 {
                Text("+\(tags.count - 2)")
                    .font(DS.Typography.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Member Avatars

    private var memberAvatars: some View {
        HStack(spacing: -8) {
            ForEach(Array((list.members ?? []).prefix(3).enumerated()), id: \.element.id) { index, member in
                Avatar(member.name ?? member.email, size: 24)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .zIndex(Double(3 - index))
            }

            if let members = list.members, members.count > 3 {
                Text("+\(members.count - 3)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(.systemGray5))
                    .clipShape(Circle())
            }
        }
    }
}
