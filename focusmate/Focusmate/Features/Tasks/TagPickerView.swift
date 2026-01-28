import SwiftUI

struct TagPickerView: View {
    @Binding var selectedTagIds: Set<Int>
    let availableTags: [TagDTO]
    var onCreateTag: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if availableTags.isEmpty {
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
                    ForEach(availableTags) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: selectedTagIds.contains(tag.id),
                            onTap: {
                                if selectedTagIds.contains(tag.id) {
                                    selectedTagIds.remove(tag.id)
                                } else {
                                    selectedTagIds.insert(tag.id)
                                }
                            }
                        )
                    }
                    
                    if let onCreateTag {
                        Button {
                            onCreateTag()
                        } label: {
                            Label("New", systemImage: "plus")
                                .font(.caption)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(Color(.secondarySystemBackground))
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
            onTap()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(tag.tagColor)
                    .frame(width: 8, height: 8)
                
                Text(tag.name)
                    .font(.caption)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(isSelected ? tag.tagColor.opacity(0.2) : Color(.secondarySystemBackground))
            .overlay(
                Capsule()
                    .stroke(isSelected ? tag.tagColor : .clear, lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = DS.Spacing.sm
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
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
            
            if currentX + size.width > maxX && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxWidth = max(maxWidth, currentX)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
