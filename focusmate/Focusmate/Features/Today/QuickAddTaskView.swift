import SwiftUI

struct QuickAddTaskView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var title = ""
    @State private var selectedList: ListDTO?
    @State private var lists: [ListDTO] = []
    @State private var isLoading = false
    @State private var isLoadingLists = true
    @State private var error: FocusmateError?

    var onTaskCreated: (() async -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                if isLoadingLists {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if lists.isEmpty {
                    Section {
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: DS.Icon.emptyList)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Create a list first")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("You need at least one list before adding tasks.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                    }
                } else {
                    TextField("Task title", text: $title)
                        .focused($isTitleFocused)

                    Picker("List", selection: $selectedList) {
                        ForEach(lists) { list in
                            Text(list.name).tag(list as ListDTO?)
                        }
                    }

                    Section {
                        Label("Due today", systemImage: DS.Icon.calendar)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Add") {
                            Task { await createTask() }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedList == nil || isLoading)
                    }
                }
            }
            .task {
                await loadLists()
                isTitleFocused = !lists.isEmpty
            }
            .alert("Error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: {
                Text(error?.message ?? "Something went wrong. Please try again.")
            }
        }
    }

    private func loadLists() async {
        isLoadingLists = true
        do {
            lists = try await state.listService.fetchLists()
            selectedList = lists.first
        } catch {
            Logger.error("Failed to load lists", error: error, category: .api)
        }
        isLoadingLists = false
    }

    private func createTask() async {
        guard let list = selectedList else { return }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        isLoading = true

        do {
            let dueDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) ?? Date()

            _ = try await state.taskService.createTask(
                listId: list.id,
                title: trimmedTitle,
                note: nil,
                dueAt: dueDate
            )

            HapticManager.success()
            await onTaskCreated?()
            dismiss()
        } catch {
            self.error = ErrorHandler.shared.handle(error, context: "Creating task")
            HapticManager.error()
            isLoading = false
        }
    }
}
