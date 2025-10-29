import SwiftUI

struct EscalationFormView: View {
  let itemId: Int
  let itemName: String
  let escalationService: EscalationService
  @Environment(\.dismiss) var dismiss
  @StateObject private var escalationViewModel: EscalationViewModel

  @State private var reason = ""
  @State private var urgency = EscalationUrgency.medium
  @State private var showingExplanationForm = false

  init(itemId: Int, itemName: String, escalationService: EscalationService) {
    self.itemId = itemId
    self.itemName = itemName
    self.escalationService = escalationService
    _escalationViewModel = StateObject(wrappedValue: EscalationViewModel(escalationService: escalationService))
  }

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Task Details")) {
          VStack(alignment: .leading, spacing: 4) {
            Text(self.itemName)
              .font(.headline)
          }
          .padding(.vertical, 4)
        }

        Section(header: Text("Escalation Details")) {
          Picker("Urgency Level", selection: self.$urgency) {
            ForEach(EscalationUrgency.allCases, id: \.self) { urgency in
              Text(urgency.rawValue.capitalized).tag(urgency)
            }
          }
          .pickerStyle(.menu)

          TextField("Reason for escalation", text: self.$reason, axis: .vertical)
            .lineLimit(3 ... 6)
        }

        Section(header: Text("Additional Actions")) {
          Button("Add Explanation Instead") {
            self.showingExplanationForm = true
          }
          .foregroundColor(.blue)
        }
      }
      .navigationTitle("Escalate Task")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Escalate") {
            Task {
              await self.escalateTask()
            }
          }
          .disabled(self.reason.isEmpty || self.escalationViewModel.isLoading)
        }
      }
      .alert("Error", isPresented: .constant(self.escalationViewModel.error != nil)) {
        Button("OK") {
          self.escalationViewModel.clearError()
        }
      } message: {
        if let error = escalationViewModel.error {
          Text(error.errorDescription ?? "An error occurred")
        }
      }
    }
    .sheet(isPresented: self.$showingExplanationForm) {
      ExplanationFormView(itemId: self.itemId, itemName: self.itemName, escalationService: self.escalationService)
    }
  }

  private func escalateTask() async {
    await self.escalationViewModel.escalateTask(
      itemId: self.itemId,
      reason: self.reason,
      urgency: self.urgency
    )

    if self.escalationViewModel.error == nil {
      self.dismiss()
    }
  }

  // Removed priorityColor since we no longer have a priority field
}
