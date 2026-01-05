import SwiftUI

struct EditListView: View {
    let list: ListDTO
    let listService: ListService
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var description: String
    @State private var selectedColor: String
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    private let colors = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]

    init(list: ListDTO, listService: ListService) {
        self.list = list
        self.listService = listService
        _name = State(initialValue: list.name)
        _description = State(initialValue: list.description ?? "")
        _selectedColor = State(initialValue: list.color ?? "blue")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    HapticManager.selection()
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateList() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .errorBanner($error)
        }
    }
    
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .blue
        }
    }

    private func updateList() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await listService.updateList(
                id: list.id,
                name: trimmedName,
                description: description.isEmpty ? nil : description,
                color: selectedColor
            )
            HapticManager.success()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("UPDATE_ERROR", error.localizedDescription)
            HapticManager.error()
        }
    }
}
