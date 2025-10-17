import Foundation

final class EscalationService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Escalation Management
    
    func getBlockingTasks() async throws -> [BlockingTask] {
        let response: BlockingTasksResponse = try await apiClient.request("GET", "escalations/blocking", body: nil as String?)
        return response.tasks
    }
    
    func escalateTask(itemId: Int, reason: String, urgency: EscalationUrgency) async throws -> Escalation {
        let request = CreateEscalationRequest(
            itemId: itemId,
            reason: reason,
            urgency: urgency
        )
        let response: EscalationResponse = try await apiClient.request("POST", "escalations", body: request)
        return response.escalation
    }
    
    func addExplanation(itemId: Int, explanation: String) async throws -> TaskExplanation {
        let request = AddExplanationRequest(explanation: explanation)
        let response: ExplanationResponse = try await apiClient.request("POST", "items/\(itemId)/explanations", body: request)
        return response.explanation
    }
    
    func getExplanations(itemId: Int) async throws -> [TaskExplanation] {
        let response: ExplanationsResponse = try await apiClient.request("GET", "items/\(itemId)/explanations", body: nil as String?)
        return response.explanations
    }
    
    func resolveEscalation(escalationId: Int, resolution: String) async throws -> Escalation {
        let request = ResolveEscalationRequest(resolution: resolution)
        let response: EscalationResponse = try await apiClient.request("PATCH", "escalations/\(escalationId)/resolve", body: request)
        return response.escalation
    }
    
    // MARK: - Request/Response Models
    
    struct CreateEscalationRequest: Codable {
        let itemId: Int
        let reason: String
        let urgency: EscalationUrgency
    }
    
    struct AddExplanationRequest: Codable {
        let explanation: String
    }
    
    struct ResolveEscalationRequest: Codable {
        let resolution: String
    }
    
    struct BlockingTasksResponse: Codable {
        let tasks: [BlockingTask]
    }
    
    struct EscalationResponse: Codable {
        let escalation: Escalation
    }
    
    struct ExplanationResponse: Codable {
        let explanation: TaskExplanation
    }
    
    struct ExplanationsResponse: Codable {
        let explanations: [TaskExplanation]
    }
}
