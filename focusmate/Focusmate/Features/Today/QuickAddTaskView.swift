import SwiftUI

struct QuickAddTaskView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var selectedList: ListDTO?
    @State private var lists: [ListDTO] = []
    @State private var isLoading = false
    
    var onTaskCreated: (() async -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Task title", text: $title)
                
                if !lists.isEmpty {
                    Picker("List", selection: $selectedList) {
                        ForEach(lists) { list in
                            Text(list.name).tag(list as ListDTO?)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("Due today")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
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
                    Button("Add") {
                        Task { await createTask() }
                    }
                    .disabled(title.isEmpty || selectedList == nil || isLoading)
                }
            }
            .task {
                await loadLists()
            }
        }
    }
    
    private func loadLists() async {
        do {
            lists = try await state.listService.fetchLists()
            selectedList = lists.first
        } catch {
            Logger.error("Failed to load lists", error: error, category: .api)
        }
    }
    
    private func createTask() async {
        guard let list = selectedList else { return }
        
        isLoading = true
        
        do {
            let dueDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: Date()) ?? Date()
            
            _ = try await state.taskService.createTask(
                listId: list.id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                note: nil,
                dueAt: dueDate
            )
            
            await onTaskCreated?()
            dismiss()
        } catch {
            Logger.error("Failed to create task", error: error, category: .api)
        }
        
        isLoading = false
    }
}
