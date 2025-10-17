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
        self._escalationViewModel = StateObject(wrappedValue: EscalationViewModel(escalationService: escalationService))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(itemName)
                            .font(.headline)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Escalation Details")) {
                    Picker("Urgency Level", selection: $urgency) {
                        ForEach(EscalationUrgency.allCases, id: \.self) { urgency in
                            Text(urgency.rawValue.capitalized).tag(urgency)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Reason for escalation", text: $reason, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("Additional Actions")) {
                    Button("Add Explanation Instead") {
                        showingExplanationForm = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Escalate Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Escalate") {
                        Task {
                            await escalateTask()
                        }
                    }
                    .disabled(reason.isEmpty || escalationViewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(escalationViewModel.error != nil)) {
                Button("OK") {
                    escalationViewModel.clearError()
                }
            } message: {
                if let error = escalationViewModel.error {
                    Text(error.errorDescription ?? "An error occurred")
                }
            }
        }
        .sheet(isPresented: $showingExplanationForm) {
            ExplanationFormView(itemId: itemId, itemName: itemName, escalationService: escalationService)
        }
    }
    
    private func escalateTask() async {
        await escalationViewModel.escalateTask(
            itemId: itemId,
            reason: reason,
            urgency: urgency
        )
        
        if escalationViewModel.error == nil {
            dismiss()
        }
    }
    
    // Removed priorityColor since we no longer have a priority field
}
