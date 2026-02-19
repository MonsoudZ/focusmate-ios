import SwiftUI

// MARK: - Tags Card

struct TaskDetailTagsCard: View {
  let tags: [TagDTO]

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Image(systemName: "tag")
          .foregroundStyle(.secondary)
        Text("Tags")
          .font(.headline)
        Spacer()
      }

      FlowLayout(spacing: DS.Spacing.sm) {
        ForEach(self.tags) { tag in
          HStack(spacing: DS.Spacing.xs) {
            Circle()
              .fill(tag.tagColor)
              .frame(width: 8, height: 8)
            Text(tag.name)
              .font(.caption)
          }
          .padding(.horizontal, DS.Spacing.sm)
          .padding(.vertical, DS.Spacing.xs)
          .background(tag.tagColor.opacity(DS.Opacity.tintBackground))
          .clipShape(Capsule())
        }
      }
    }
    .card()
  }
}

// MARK: - Notes Card

struct TaskDetailNotesCard: View {
  let note: String

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Image(systemName: "note.text")
          .foregroundStyle(.secondary)
        Text("Notes")
          .font(.headline)
        Spacer()
      }

      Text(self.note)
        .font(.body)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .card()
  }
}

// MARK: - Visibility Card

struct TaskDetailVisibilityCard: View {
  let members: [ListMemberDTO]
  let listName: String

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Image(systemName: "eye")
          .foregroundStyle(.secondary)
        Text("Visible to")
          .font(.headline)
        Spacer()
        Text(self.listName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      FlowLayout(spacing: DS.Spacing.sm) {
        ForEach(self.members) { member in
          HStack(spacing: DS.Spacing.xs) {
            Avatar(member.displayName, size: 20)
            Text(member.displayName)
              .font(.caption)
          }
          .padding(.horizontal, DS.Spacing.sm)
          .padding(.vertical, DS.Spacing.xs)
          .background(Color(.tertiarySystemFill))
          .clipShape(Capsule())
        }
      }
    }
    .card()
  }
}

// MARK: - Missed Reason Card

struct TaskDetailMissedReasonCard: View {
  let reason: String

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      HStack {
        Image(systemName: "exclamationmark.bubble")
          .foregroundStyle(DS.Colors.warning)
        Text("Completion Note")
          .font(.headline)
        Spacer()
      }

      Text(self.reason)
        .font(.body)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(DS.Spacing.md)
    .background(DS.Colors.warning.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
  }
}
