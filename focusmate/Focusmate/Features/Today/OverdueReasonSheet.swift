import SwiftUI

struct OverdueReasonSheet: View {
    let task: TaskDTO
    let onSubmit: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var selectedReason: String?
    @State private var customReason: String = ""
    
    private let reasons = [
        ("forgot", "I forgot"),
        ("too_busy", "Too busy"),
        ("blocked", "Waiting on someone/something"),
        ("deprioritized", "Deprioritized"),
        ("didnt_feel_like_it", "Didn't feel like it"),
        ("other", "Other")
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                // Header
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(DS.Colors.warning)
                    
                    Text("Why was this task late?")
                        .font(.title2.weight(.semibold))
                    
                    Text(task.title)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.lg)
                
                // Reason options
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(reasons, id: \.0) { reason in
                        ReasonButton(
                            title: reason.1,
                            isSelected: selectedReason == reason.0,
                            action: { selectedReason = reason.0 }
                        )
                    }
                }
                
                // Custom reason field (if "other" selected)
                if selectedReason == "other" {
                    TextField("Explain briefly...", text: $customReason)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Submit button
                Button {
                    let reason = selectedReason == "other" ? customReason : (selectedReason ?? "")
                    onSubmit(reason)
                } label: {
                    Text("Complete Task")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .padding(.horizontal)
                .padding(.bottom, DS.Spacing.lg)
            }
            .navigationTitle("Overdue Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        guard let selected = selectedReason else { return false }
        if selected == "other" {
            return !customReason.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }
}

struct ReasonButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.body)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.accent)
                }
            }
            .padding(DS.Spacing.md)
            .background(isSelected ? DS.Colors.accent.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(DS.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSelected ? DS.Colors.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
