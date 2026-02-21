import SwiftUI

struct ListRowView: View {
  let list: ListDTO

  private var isSharedList: Bool {
    self.list.role != nil && self.list.role != "owner"
  }

  private var hasMembers: Bool {
    guard let members = list.members else { return false }
    return members.count > 1
  }

  var body: some View {
    HStack(spacing: DS.Spacing.md) {
      // Progress ring with color
      self.progressRing

      // List info
      VStack(alignment: .leading, spacing: DS.Spacing.xs) {
        HStack(spacing: DS.Spacing.sm) {
          Text(self.list.name)
            .font(DS.Typography.bodyMedium)

          if let listType = list.list_type, listType != "tasks" {
            Text(listType == "habit_tracker" ? "Habit" : listType.capitalized)
              .scaledFont(size: 10, weight: .medium, relativeTo: .caption2)
              .foregroundStyle(DS.Colors.accent)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(DS.Colors.accent.opacity(0.12))
              .clipShape(Capsule())
          }

          if self.hasMembers {
            Image(systemName: "person.2.fill")
              .scaledFont(size: 10, relativeTo: .caption2)
              .foregroundStyle(.secondary)
          }

          if self.list.hasOverdue {
            self.overdueBadge
          }
        }

        HStack(spacing: DS.Spacing.sm) {
          let total = self.list.parent_tasks_count ?? self.list.tasks_count
          if let total {
            if let completed = list.completed_tasks_count {
              // API contract mismatch: `completed_tasks_count` includes subtask
              // completions, but `parent_tasks_count`/`tasks_count` only counts
              // parent tasks. Until the Rails serializer aligns the scopes
              // (e.g. COUNT(*) WHERE parent_id IS NULL for both), clamp here
              // to prevent displaying "7/5 done".
              let clamped = min(completed, total)
              Text("\(clamped)/\(total) done")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            } else {
              Text(total == 1 ? "1 task" : "\(total) tasks")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
            }
          }

          if self.isSharedList {
            Text("•")
              .font(DS.Typography.caption)
              .foregroundStyle(.secondary)

            Text(self.list.role?.capitalized ?? "Shared")
              .font(DS.Typography.caption)
              .foregroundStyle(DS.Colors.accent)
          }

          if let tags = list.tags, !tags.isEmpty {
            self.listTagsView(tags)
          }
        }
      }

      Spacer()

      // Member avatars for shared lists
      if self.hasMembers {
        self.memberAvatars
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
    if self.list.completed_tasks_count != nil {
      // Show progress ring when we have completion data
      ZStack {
        Circle()
          .stroke(self.list.listColor.opacity(0.2), lineWidth: 3)

        Circle()
          .trim(from: 0, to: self.list.progress)
          .stroke(self.list.listColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .rotationEffect(.degrees(-90))

        if self.list.progress >= 1.0 {
          Image(systemName: "checkmark")
            .scaledFont(size: 12, weight: .bold, relativeTo: .caption)
            .foregroundStyle(self.list.listColor)
        }
      }
      .frame(width: 32, height: 32)
    } else {
      // Fall back to color bar when no completion data
      ColorBar(color: self.list.listColor)
    }
  }

  // MARK: - Overdue Badge

  private var overdueBadge: some View {
    HStack(spacing: 2) {
      Image(systemName: "exclamationmark.triangle.fill")
        .scaledFont(size: 10, relativeTo: .caption2)
      Text("\(self.list.overdue_tasks_count ?? 0)")
        .scaledFont(size: 11, weight: .medium, relativeTo: .caption2)
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
          .background(tag.tagColor.opacity(DS.Opacity.tintBackground))
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
      ForEach(Array((self.list.members ?? []).prefix(3).enumerated()), id: \.element.id) { index, member in
        Avatar(member.displayName, size: 24)
          .overlay(
            Circle()
              .stroke(Color(.systemBackground), lineWidth: 2)
          )
          .zIndex(Double(3 - index))
      }

      if let members = list.members, members.count > 3 {
        Text("+\(members.count - 3)")
          .scaledFont(size: 10, weight: .medium, relativeTo: .caption2)
          .foregroundStyle(.secondary)
          .frame(width: 24, height: 24)
          .background(Color(.systemGray5))
          .clipShape(Circle())
      }
    }
  }
}
