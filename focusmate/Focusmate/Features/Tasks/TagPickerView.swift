import SwiftUI

struct TagPickerView: View {
    @Binding var selectedTagIds: Set<Int>
    let availableTags: [TagDTO]
    var onCreateTag: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if availableTags.isEmpty {
                HStack {
                    Text("No tags yet")
                        .font(DesignSystem.Typography.caption1)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    if let onCreateTag = onCreateTag {
                        Button("Create Tag") {
                            onCreateTag()
                        }
                        .font(DesignSystem.Typography.caption1)
                    }
                }
            } else {
                FlowLayout(spacing: 8) {
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
                    
                    if let onCreateTag = onCreateTag {
                        Button {
                            onCreateTag()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("New")
                            }
                            .font(DesignSystem.Typography.caption1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DesignSystem.Colors.secondaryBackground)
                            .cornerRadius(16)
                        }
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
            HStack(spacing: 4) {
                Circle()
                    .fill(tag.tagColor)
                    .frame(width: 8, height: 8)
                
                Text(tag.name)
                    .font(DesignSystem.Typography.caption1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tag.tagColor.opacity(0.2) : DesignSystem.Colors.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? tag.tagColor : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
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
