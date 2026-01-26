import SwiftUI

struct OnboardingCreateListPage: View {
    let onNext: () -> Void

    @EnvironmentObject private var state: AppState

    @State private var listName: String = ""
    @State private var selectedColor: String = "blue"
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: DS.Spacing.xxl) {
            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Text("Create Your First List")
                    .font(.largeTitle.weight(.bold))

                Text("Lists help you organize tasks by project or area.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DS.Spacing.lg) {
                TextField("List name", text: $listName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Color")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    ListColorPicker(selected: $selectedColor)
                }
            }
            .card()

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.error)
            }

            Spacer()

            VStack(spacing: DS.Spacing.md) {
                Button(action: createList) {
                    if isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)

                Button("Skip") {
                    onNext()
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.xl)
    }

    private func createList() {
        let trimmed = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                _ = try await state.listService.createList(
                    name: trimmed,
                    description: nil,
                    color: selectedColor
                )
                await MainActor.run {
                    onNext()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create list. Please try again."
                    isCreating = false
                }
            }
        }
    }
}
