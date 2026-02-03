import SwiftUI

struct RescheduleSheet: View {
    let task: TaskDTO
    let onSubmit: (Date, String) async -> Void

    @Environment(\.dismiss) var dismiss
    @State private var step: Step = .selectDate
    @State private var selectedDate: Date
    @State private var includeTime: Bool
    @State private var selectedTime: Date
    @State private var selectedReason: String?
    @State private var customReason: String = ""
    @State private var isSubmitting = false

    private enum Step {
        case selectDate
        case selectReason
    }

    private let reasons = [
        ("scope_changed", "Scope changed"),
        ("priorities_shifted", "Priorities shifted"),
        ("blocked", "Waiting on someone/something"),
        ("underestimated", "Underestimated time needed"),
        ("unexpected_work", "Unexpected work came up"),
        ("not_ready", "Not ready to start yet"),
        ("other", "Other")
    ]

    init(task: TaskDTO, onSubmit: @escaping (Date, String) async -> Void) {
        self.task = task
        self.onSubmit = onSubmit
        let currentDate = task.dueDate ?? Date()
        _selectedDate = State(initialValue: currentDate)
        _selectedTime = State(initialValue: currentDate)
        // Check if task has specific time (not midnight)
        let hour = Calendar.current.component(.hour, from: currentDate)
        let minute = Calendar.current.component(.minute, from: currentDate)
        _includeTime = State(initialValue: !(hour == 0 && minute == 0))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .selectDate:
                    dateSelectionView
                case .selectReason:
                    reasonSelectionView
                }
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Date Selection

    private var dateSelectionView: some View {
        Form {
            Section {
                DatePicker(
                    "New Date",
                    selection: $selectedDate,
                    in: Calendar.current.startOfDay(for: Date())...,
                    displayedComponents: [.date]
                )

                Toggle("Include specific time", isOn: $includeTime)

                if includeTime {
                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        in: minimumTime...,
                        displayedComponents: [.hourAndMinute]
                    )
                }
            } header: {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
            }

            Section {
                Button {
                    withAnimation { step = .selectReason }
                } label: {
                    HStack {
                        Spacer()
                        Text("Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
    }

    private var minimumTime: Date {
        if Calendar.current.isDateInToday(selectedDate) {
            return Date()
        }
        return Calendar.current.startOfDay(for: selectedDate)
    }

    // MARK: - Reason Selection

    private var reasonSelectionView: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 50))
                    .foregroundStyle(DS.Colors.accent)

                Text("Why are you rescheduling?")
                    .font(DS.Typography.title2)

                Text(task.title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                dateChangeLabel
            }
            .padding(.top, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(reasons, id: \.0) { reason in
                    ReasonButton(
                        title: reason.1,
                        isSelected: selectedReason == reason.0,
                        action: { selectedReason = reason.0 }
                    )
                }
            }

            if selectedReason == "other" {
                TextField("Explain briefly...", text: $customReason)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }

            Spacer()

            HStack(spacing: DS.Spacing.md) {
                Button {
                    withAnimation { step = .selectDate }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(IntentiaSecondaryButtonStyle())

                Button {
                    Task { await submitReschedule() }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Reschedule")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(IntentiaPrimaryButtonStyle())
                .disabled(!canSubmit || isSubmitting)
            }
            .padding(.horizontal)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    private var dateChangeLabel: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let oldDate = task.dueDate {
                Text(oldDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
                    .strikethrough()
            }
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(finalDate.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(DS.Colors.accent)
        }
        .font(.caption)
        .padding(.top, DS.Spacing.xs)
    }

    private var finalDate: Date {
        let calendar = Calendar.current
        if includeTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
            return calendar.date(bySettingHour: timeComponents.hour ?? 17,
                                  minute: timeComponents.minute ?? 0,
                                  second: 0,
                                  of: selectedDate) ?? selectedDate
        } else {
            return calendar.startOfDay(for: selectedDate)
        }
    }

    private var canSubmit: Bool {
        guard let selected = selectedReason else { return false }
        if selected == "other" {
            return !customReason.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private func submitReschedule() async {
        isSubmitting = true
        let reason = selectedReason == "other" ? customReason : (selectedReason ?? "")
        await onSubmit(finalDate, reason)
        isSubmitting = false
    }
}
