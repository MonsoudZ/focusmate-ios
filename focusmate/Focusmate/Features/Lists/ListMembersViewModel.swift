import Foundation

@MainActor
@Observable
final class ListMembersViewModel {
    var memberships: [MembershipDTO] = []
    var isLoading = true
    var error: FocusmateError?
    var showingInvite = false
    var memberToRemove: MembershipDTO?

    let list: ListDTO
    let apiClient: APIClient

    init(list: ListDTO, apiClient: APIClient) {
        self.list = list
        self.apiClient = apiClient
    }

    func loadMembers() async {
        isLoading = true
        do {
            let response: MembershipsResponse = try await apiClient.request(
                "GET",
                API.Lists.memberships(String(list.id)),
                body: nil as String?
            )
            memberships = response.memberships
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
        isLoading = false
    }

    func removeMember(_ membership: MembershipDTO) async {
        do {
            let _: EmptyResponse = try await apiClient.request(
                "DELETE",
                API.Lists.membership(String(list.id), String(membership.id)),
                body: nil as String?
            )
            memberships.removeAll { $0.id == membership.id }
            memberToRemove = nil
        } catch let err as FocusmateError {
            error = err
        } catch {
            self.error = ErrorHandler.shared.handle(error)
        }
    }
}
