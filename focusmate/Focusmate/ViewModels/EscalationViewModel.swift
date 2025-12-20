import Combine
import Foundation

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
    self.isLoading = true
    self.error = nil

    do {
      self.blockingTasks = try await self.escalationService.getBlockingTasks()
      Logger.info("EscalationViewModel: Loaded \(self.blockingTasks.count) blocking tasks", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("EscalationViewModel: Failed to load blocking tasks: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func escalateTask(itemId: Int, reason: String, urgency: EscalationUrgency) async {
    self.isLoading = true
    self.error = nil

    do {
      let escalation = try await escalationService.escalateTask(
        itemId: itemId,
        reason: reason,
        urgency: urgency
      )
      self.escalations.append(escalation)
      Logger.info("EscalationViewModel: Escalated task \(itemId) with urgency \(urgency.rawValue)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("EscalationViewModel: Failed to escalate task: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func addExplanation(itemId: Int, explanation: String, type _: ExplanationType) async {
    self.isLoading = true
    self.error = nil

    do {
      _ = try await self.escalationService.addExplanation(
        itemId: itemId,
        explanation: explanation
      )
      Logger.info("EscalationViewModel: Added explanation for task \(itemId)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("EscalationViewModel: Failed to add explanation: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func resolveEscalation(escalationId: Int, resolution: String) async {
    self.isLoading = true
    self.error = nil

    do {
      let resolvedEscalation = try await escalationService.resolveEscalation(
        escalationId: escalationId,
        resolution: resolution
      )

      if let index = escalations.firstIndex(where: { $0.id == escalationId }) {
        self.escalations[index] = resolvedEscalation
      }
      Logger.info("EscalationViewModel: Resolved escalation \(escalationId)", category: .database)
    } catch {
      self.error = ErrorHandler.shared.handle(error)
      Logger.error("EscalationViewModel: Failed to resolve escalation: \(error)", category: .database)
    }

    self.isLoading = false
  }

  func clearError() {
    self.error = nil
  }
}
