import SwiftUI

struct TagPickerView: View {
  @Binding var selectedTagIds: Set<Int>
  let availableTags: [TagDTO]
  var onCreateTag: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
      if self.availableTags.isEmpty {
        HStack {
          Text("No tags yet")
            .font(.caption)
            .foregroundStyle(.secondary)

          Spacer()

          if let onCreateTag {
            Button("Create Tag") {
              onCreateTag()
            }
            .font(.caption)
          }
        }
      } else {
        FlowLayout(spacing: DS.Spacing.sm) {
          ForEach(self.availableTags) { tag in
            TagChip(
              tag: tag,
              isSelected: self.selectedTagIds.contains(tag.id),
              onTap: {
                if self.selectedTagIds.contains(tag.id) {
                  self.selectedTagIds.remove(tag.id)
                } else {
                  self.selectedTagIds.insert(tag.id)
                }
              }
            )
          }

          if let onCreateTag {
            Button {
              onCreateTag()
            } label: {
              HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "plus")
                  .font(.caption.weight(.semibold))
                Text("New Tag")
                  .font(.caption)
              }
              .foregroundStyle(DS.Colors.accent)
              .padding(.horizontal, DS.Spacing.md)
              .padding(.vertical, DS.Spacing.sm)
              .background(DS.Colors.accent.opacity(0.12))
              .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }
}

struct TagChip: View {
  let tag: TagDTO
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button {
      HapticManager.selection()
      self.onTap()
    } label: {
      HStack(spacing: DS.Spacing.xs) {
        Circle()
          .fill(self.tag.tagColor)
          .frame(width: 8, height: 8)

        Text(self.tag.name)
          .font(.caption)
      }
      .padding(.horizontal, DS.Spacing.md)
      .padding(.vertical, DS.Spacing.sm)
      .background(self.isSelected ? self.tag.tagColor
        .opacity(DS.Opacity.tintBackgroundActive) : Color(.secondarySystemBackground))
      .overlay(
        Capsule()
          .stroke(self.isSelected ? self.tag.tagColor : .clear, lineWidth: 1.5)
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

/// Simple flow layout for tags
struct FlowLayout: Layout {
  var spacing: CGFloat = DS.Spacing.sm

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = self.layout(subviews: subviews, proposal: proposal)
    return result.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let result = self.layout(subviews: subviews, proposal: proposal)
    for (index, position) in result.positions.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, positions: [CGPoint]) {
    var positions: [CGPoint] = []
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxWidth: CGFloat = 0

    let maxX = proposal.width ?? .infinity

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)

      if currentX + size.width > maxX, currentX > 0 {
        currentX = 0
        currentY += lineHeight + self.spacing
        lineHeight = 0
      }

      positions.append(CGPoint(x: currentX, y: currentY))
      lineHeight = max(lineHeight, size.height)
      currentX += size.width + self.spacing
      maxWidth = max(maxWidth, currentX)
    }

    return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
  }
}
