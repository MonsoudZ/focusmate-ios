import SwiftUI

struct TaskActionSheet: View {
  let item: Item
  let itemViewModel: ItemViewModel
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var appState: AppState

  @State private var showingReassign = false
  @State private var showingExplanation = false
  @State private var showingEscalation = false
  @State private var showingSnooze = false
  @State private var completionNotes = ""
  @State private var showingCompletionForm = false
  @State private var showingEditForm = false

  private var isOverdue: Bool {
    guard let dueDate = item.dueDate else { return false }
    return dueDate < Date()
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 0) {
          // Task Header
          VStack(alignment: .leading, spacing: 16) {
            // Title with overdue highlighting
            HStack {
              Text(self.item.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(self.isOverdue ? .red : .primary)

              if self.isOverdue {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.red)
                  .font(.title3)
              }
            }

            // Description
            if let description = item.description, !description.isEmpty {
              Text(description)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.vertical, 8)
            } else {
              Text("No description")
                .font(.body)
                .foregroundColor(.secondary)
                .italic()
                .padding(.vertical, 8)
            }

          // Due Date and Overdue Status
          VStack(alignment: .leading, spacing: 8) {
            if let dueDate = item.dueDate {
              HStack {
                Image(systemName: "calendar")
                  .foregroundColor(.blue)
                Text("Due: \(dueDate, style: .date)")
                  .font(.subheadline)
                  .foregroundColor(dueDate < Date() ? .red : .primary)

                if dueDate < Date() {
                  let overdueDays = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
                  Text("(\(overdueDays) day\(overdueDays == 1 ? "" : "s") overdue)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }
              }
            } else {
              HStack {
                Image(systemName: "calendar")
                  .foregroundColor(.gray)
                Text("No due date")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
          }

          // Visibility Information
          HStack {
            Image(systemName: self.item.is_visible ? "eye" : "eye.slash")
              .foregroundColor(self.item.is_visible ? .green : .orange)
            Text(self.item.is_visible ? "Visible to others" : "Private task")
              .font(.subheadline)
              .foregroundColor(self.item.is_visible ? .green : .orange)
          }

          // Creation Date
          HStack {
            Image(systemName: "clock")
              .foregroundColor(.gray)
            Text("Created \(self.item.created_at)")
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Divider()
        }
        .padding()
        .background(self.isOverdue ? Color.red.opacity(0.1) : Color.clear)
        .overlay(
          self.isOverdue ?
            RoundedRectangle(cornerRadius: 8)
            .stroke(Color.red, lineWidth: 2) :
            nil
        )

        // Subtasks Section
        if self.item.has_subtasks || self.item.subtasks_count > 0 {
          VStack(spacing: 0) {
            SubtaskListView(taskId: self.item.id, appState: self.appState)
              .frame(height: 300)
          }
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .padding(.horizontal)
          .padding(.bottom)
        }

        // Action Buttons
        VStack(spacing: 16) {
          // Primary Actions
          VStack(spacing: 12) {
            if !self.item.isCompleted {
              Button(action: { self.showingCompletionForm = true }) {
                HStack {
                  Image(systemName: "checkmark.circle")
                  Text("Mark as Complete")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
            } else {
              Button(action: { self.toggleCompletion() }) {
                HStack {
                  Image(systemName: "arrow.uturn.backward.circle")
                  Text("Mark as Incomplete")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
            }

            Button(action: { self.showingReassign = true }) {
              HStack {
                Image(systemName: "person.2")
                Text("Reassign Task")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.blue)
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
          }

          // Secondary Actions
          VStack(spacing: 8) {
            if self.item.can_be_snoozed && !self.item.isCompleted {
              Button(action: { self.showingSnooze = true }) {
                HStack {
                  Image(systemName: "clock.badge.checkmark")
                  Text("Snooze Task")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.indigo)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
              }
            }

            Button(action: { self.showingExplanation = true }) {
              HStack {
                Image(systemName: "text.bubble")
                Text("Add Explanation")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.purple)
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Button(action: { self.showingEscalation = true }) {
              HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Escalate Task")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.red)
              .foregroundColor(.white)
              .clipShape(RoundedRectangle(cornerRadius: 8))
            }
          }
        }
        .padding()
      }
    }
      .navigationTitle("Task Actions")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: { self.showingEditForm = true }) {
            Image(systemName: "pencil")
              .foregroundColor(.blue)
          }
          .disabled(!self.item.can_edit)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            self.dismiss()
          }
        }
      }
      .sheet(isPresented: self.$showingEditForm) {
        EditItemView(item: self.item, itemService: ItemService(
          apiClient: APIClient(tokenProvider: { AppState().auth.jwt }),
          swiftDataManager: SwiftDataManager.shared
        ))
      }
      .sheet(isPresented: self.$showingReassign) {
        ReassignView(item: self.item, itemViewModel: self.itemViewModel)
      }
      .sheet(isPresented: self.$showingExplanation) {
        ExplanationFormView(
          itemId: self.item.id,
          itemName: self.item.title,
          escalationService: EscalationService(apiClient: APIClient { nil })
        )
      }
      .sheet(isPresented: self.$showingEscalation) {
        EscalationFormView(
          itemId: self.item.id,
          itemName: self.item.title,
          escalationService: EscalationService(apiClient: APIClient { nil })
        )
      }
      .sheet(isPresented: self.$showingCompletionForm) {
        CompletionFormView(item: self.item, itemViewModel: self.itemViewModel)
      }
      .sheet(isPresented: self.$showingSnooze) {
        SnoozePickerView(item: self.item, itemViewModel: self.itemViewModel)
      }
    }
  }

  private func toggleCompletion() {
    Task {
      await self.itemViewModel.completeItem(
        id: self.item.id,
        completed: !self.item.isCompleted,
        completionNotes: nil
      )
    }
  }

  // Removed priorityColor since Item no longer has a Priority enum
}

struct CompletionFormView: View {
  let item: Item
  let itemViewModel: ItemViewModel
  @Environment(\.dismiss) var dismiss

  @State private var completionNotes = ""

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Task Details")) {
          VStack(alignment: .leading, spacing: 4) {
            Text(self.item.title)
              .font(.headline)

            if let description = item.description {
              Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
          .padding(.vertical, 4)
        }

        Section(header: Text("Completion Notes")) {
          TextField("Add notes about completion (optional)", text: self.$completionNotes, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section(footer: Text("Completion notes help track what was accomplished and any important details.")) {
          EmptyView()
        }
      }
      .navigationTitle("Complete Task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Complete") {
            Task {
              await self.completeTask()
            }
          }
          .disabled(self.itemViewModel.isLoading)
        }
      }
    }
  }

  private func completeTask() async {
    await self.itemViewModel.completeItem(
      id: self.item.id,
      completed: true,
      completionNotes: self.completionNotes.isEmpty ? nil : self.completionNotes
    )

    if self.itemViewModel.error == nil {
      self.dismiss()
    }
  }
}
