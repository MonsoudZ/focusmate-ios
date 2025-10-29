import SwiftUI

struct ExplanationFormView: View {
  let itemId: Int
  let itemName: String
  let escalationService: EscalationService
  @Environment(\.dismiss) var dismiss
  @StateObject private var escalationViewModel: EscalationViewModel

  @State private var explanation = ""
  @State private var explanationType = ExplanationType.missedDeadline

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

        Section(header: Text("Explanation Details")) {
          Picker("Explanation Type", selection: self.$explanationType) {
            ForEach(ExplanationType.allCases, id: \.self) { type in
              HStack {
                Image(systemName: type.icon)
                Text(type.rawValue)
              }
              .tag(type)
            }
          }
          .pickerStyle(.menu)

          TextField("Explain what happened", text: self.$explanation, axis: .vertical)
            .lineLimit(4 ... 8)
        }

        Section(
          footer: Text("Adding an explanation helps your coach understand the situation and provide better support.")
        ) {
          EmptyView()
        }
      }
      .navigationTitle("Add Explanation")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            self.dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Add Explanation") {
            Task {
              await self.addExplanation()
            }
          }
          .disabled(self.explanation.isEmpty || self.escalationViewModel.isLoading)
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
  }

  private func addExplanation() async {
    await self.escalationViewModel.addExplanation(
      itemId: self.itemId,
      explanation: self.explanation,
      type: self.explanationType
    )

    if self.escalationViewModel.error == nil {
      self.dismiss()
    }
  }
}
