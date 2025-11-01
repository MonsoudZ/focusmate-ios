import SwiftUI

struct SubtaskListView: View {
  let taskId: Int
  @StateObject private var viewModel: SubtaskViewModel
  @State private var showingAddSubtask = false
  @State private var newSubtaskTitle = ""
  @State private var newSubtaskDescription = ""

  init(taskId: Int, appState: AppState) {
    self.taskId = taskId
    _viewModel = StateObject(wrappedValue: SubtaskViewModel(
      taskId: taskId,
      subtaskService: SubtaskService(
        apiClient: appState.auth.api,
        swiftDataManager: appState.swiftDataManager
      )
    ))
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Subtasks")
          .font(.headline)
          .foregroundColor(.primary)

        Spacer()

        if !viewModel.subtasks.isEmpty {
          Text("\(viewModel.completedCount)/\(viewModel.subtasks.count)")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Button(action: {
          showingAddSubtask = true
        }) {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(.blue)
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 12)
      .background(Color(.systemGray6))

      // Subtask List
      if viewModel.isLoading && viewModel.subtasks.isEmpty {
        ProgressView()
          .padding()
      } else if viewModel.subtasks.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "checklist")
            .font(.system(size: 40))
            .foregroundColor(.secondary)
          Text("No subtasks yet")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Text("Break this task into smaller steps")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
      } else {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(viewModel.subtasks) { subtask in
              SubtaskRow(
                subtask: subtask,
                onToggle: {
                  Task {
                    await viewModel.toggleSubtask(id: subtask.id)
                  }
                },
                onDelete: {
                  Task {
                    await viewModel.deleteSubtask(id: subtask.id)
                  }
                }
              )
              .padding(.horizontal)
              .padding(.vertical, 4)

              if subtask.id != viewModel.subtasks.last?.id {
                Divider()
                  .padding(.horizontal)
              }
            }
          }
        }
      }
    }
    .sheet(isPresented: $showingAddSubtask) {
      NavigationView {
        Form {
          Section(header: Text("Subtask Details")) {
            TextField("Title", text: $newSubtaskTitle)
              .autocapitalization(.sentences)

            TextField("Description (optional)", text: $newSubtaskDescription, axis: .vertical)
              .lineLimit(3...6)
              .autocapitalization(.sentences)
          }
        }
        .navigationTitle("New Subtask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              showingAddSubtask = false
              newSubtaskTitle = ""
              newSubtaskDescription = ""
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") {
              Task {
                await viewModel.createSubtask(
                  title: newSubtaskTitle,
                  description: newSubtaskDescription.isEmpty ? nil : newSubtaskDescription
                )
                showingAddSubtask = false
                newSubtaskTitle = ""
                newSubtaskDescription = ""
              }
            }
            .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
    .alert("Error", isPresented: .constant(viewModel.error != nil)) {
      Button("OK") {
        viewModel.clearError()
      }
    } message: {
      if let error = viewModel.error {
        Text(error.message)
      }
    }
    .task {
      await viewModel.loadSubtasks()
    }
  }
}

struct SubtaskRow: View {
  let subtask: Subtask
  let onToggle: () -> Void
  let onDelete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggle) {
        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
          .foregroundColor(subtask.isCompleted ? .green : .gray)
          .font(.system(size: 22))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Text(subtask.title)
          .font(.body)
          .foregroundColor(subtask.isCompleted ? .secondary : .primary)
          .strikethrough(subtask.isCompleted)

        if let description = subtask.description, !description.isEmpty {
          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(2)
        }
      }

      Spacer()

      Button(action: onDelete) {
        Image(systemName: "trash")
          .foregroundColor(.red)
          .font(.system(size: 16))
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Preview

#Preview {
  SubtaskListView(taskId: 1, appState: AppState())
}
