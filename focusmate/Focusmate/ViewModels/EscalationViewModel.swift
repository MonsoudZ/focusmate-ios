import Foundation
import Combine

@MainActor
final class EscalationViewModel: ObservableObject {
    @Published var blockingTasks: [BlockingTask] = []
    @Published var escalations: [Escalation] = []
    @Published var isLoading = false
    @Published var error: FocusmateError?
    
    let escalationService: EscalationService
    private var cancellables = Set<AnyCancellable>()
    
    init(escalationService: EscalationService) {
        self.escalationService = escalationService
    }
    
    func loadBlockingTasks() async {
        isLoading = true
        error = nil
        
        do {
            blockingTasks = try await escalationService.getBlockingTasks()
            print("✅ EscalationViewModel: Loaded \(blockingTasks.count) blocking tasks")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ EscalationViewModel: Failed to load blocking tasks: \(error)")
        }
        
        isLoading = false
    }
    
    func escalateTask(itemId: Int, reason: String, urgency: EscalationUrgency) async {
        isLoading = true
        error = nil
        
        do {
            let escalation = try await escalationService.escalateTask(
                itemId: itemId,
                reason: reason,
                urgency: urgency
            )
            escalations.append(escalation)
            print("✅ EscalationViewModel: Escalated task \(itemId) with urgency \(urgency.rawValue)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ EscalationViewModel: Failed to escalate task: \(error)")
        }
        
        isLoading = false
    }
    
    func addExplanation(itemId: Int, explanation: String, type: ExplanationType) async {
        isLoading = true
        error = nil
        
        do {
            _ = try await escalationService.addExplanation(
                itemId: itemId,
                explanation: explanation
            )
            print("✅ EscalationViewModel: Added explanation for task \(itemId)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ EscalationViewModel: Failed to add explanation: \(error)")
        }
        
        isLoading = false
    }
    
    func resolveEscalation(escalationId: Int, resolution: String) async {
        isLoading = true
        error = nil
        
        do {
            let resolvedEscalation = try await escalationService.resolveEscalation(
                escalationId: escalationId,
                resolution: resolution
            )
            
            if let index = escalations.firstIndex(where: { $0.id == escalationId }) {
                escalations[index] = resolvedEscalation
            }
            print("✅ EscalationViewModel: Resolved escalation \(escalationId)")
        } catch {
            self.error = ErrorHandler.shared.handle(error)
            print("❌ EscalationViewModel: Failed to resolve escalation: \(error)")
        }
        
        isLoading = false
    }
    
    func clearError() {
        error = nil
    }
}
