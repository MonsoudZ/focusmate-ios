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
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .font(.system(size: 50))
                        .foregroundColor(DesignSystem.Colors.warning)
                    
                    Text("Why was this task late?")
                        .font(DesignSystem.Typography.title2)
                    
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.Spacing.lg)
                
                // Reason options
                VStack(spacing: DesignSystem.Spacing.sm) {
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
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmit)
                .padding(.horizontal)
                .padding(.bottom, DesignSystem.Spacing.lg)
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
                    .font(DesignSystem.Typography.body)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? DesignSystem.Colors.primaryLight : DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? DesignSystem.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
