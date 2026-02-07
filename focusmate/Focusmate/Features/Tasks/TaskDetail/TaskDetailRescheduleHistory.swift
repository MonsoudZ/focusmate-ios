import SwiftUI

/// Reschedule history card showing previous date changes
struct TaskDetailRescheduleHistoryCard: View {
    let rescheduleEvents: [RescheduleEventDTO]
    let rescheduleCount: Int
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(DS.Colors.warning)
                    Text("Reschedule History")
                        .font(.headline)
                    Text("(\(rescheduleCount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal, DS.Spacing.md)

                ForEach(rescheduleEvents) { event in
                    RescheduleEventRow(event: event)
                    if event.id != rescheduleEvents.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - Reschedule Event Row

private struct RescheduleEventRow: View {
    let event: RescheduleEventDTO

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                if let oldDate = event.previousDueDate {
                    Text(oldDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                        .strikethrough()
                }
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let newDate = event.newDueDate {
                    Text(newDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .font(.subheadline)

            Text(event.reasonLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let createdAt = event.createdDate {
                Text(createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DS.Spacing.md)
    }
}
