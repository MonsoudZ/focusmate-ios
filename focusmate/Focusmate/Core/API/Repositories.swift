import Foundation

final class ListsRepo {
    private let api: NewAPIClient
    init(api: NewAPIClient) { self.api = api }

    func index(cursor: String? = nil) async throws -> Page<ListDTO> {
        try await api.request("GET", API.Lists.root, query: cursor.map { [URLQueryItem(name:"cursor", value:$0)] })
    }
    
    func create(title: String, visibility: String = "private") async throws -> ListDTO {
        try await api.request("POST", API.Lists.root,
                              body: CreateListRequest(list: .init(name: title, description: nil, visibility: visibility)),
                              idempotencyKey: UUID().uuidString)
    }

    func update(id: Int, title: String? = nil, visibility: String? = nil) async throws -> ListDTO {
        try await api.request("PATCH", API.Lists.id(String(id)),
                              body: UpdateListRequest(list: .init(name: title, description: nil, visibility: visibility)))
    }

    func destroy(id: Int) async throws {
        _ = try await api.request("DELETE", API.Lists.id(String(id))) as Empty
    }
}

final class TasksRepo {
    private let api: NewAPIClient
    init(api: NewAPIClient) { self.api = api }

    func index(listId: Int, cursor: String? = nil) async throws -> Page<TaskDTO> {
        try await api.request("GET", API.Lists.tasks(String(listId)),
                              query: cursor.map { [URLQueryItem(name:"cursor", value:$0)] })
    }

    func create(listId: Int, title: String, notes: String? = nil, visibility: String = "private") async throws -> TaskDTO {
        try await api.request("POST", API.Lists.tasks(String(listId)),
            body: CreateTaskRequest(task: .init(title: title, notes: notes, visibility: visibility)),
            idempotencyKey: UUID().uuidString)
    }

    func update(listId: Int, id: Int, title: String? = nil, notes: String? = nil, visibility: String? = nil) async throws -> TaskDTO {
        try await api.request("PATCH", API.Lists.task(String(listId), String(id)),
                              body: UpdateTaskRequest(task: .init(title: title, notes: notes, visibility: visibility)))
    }

    func destroy(listId: Int, id: Int) async throws {
        _ = try await api.request("DELETE", API.Lists.task(String(listId), String(id))) as Empty
    }

    func complete(listId: Int, id: Int, done: Bool) async throws -> TaskDTO {
        let path = API.Lists.taskAction(String(listId), String(id), done ? "complete" : "uncomplete")
        return try await api.request("PATCH", path)
    }

    func reassign(listId: Int, id: Int, assigneeId: String) async throws -> TaskDTO {
        try await api.request("PATCH", API.Lists.taskAction(String(listId), String(id), "reassign"),
                              body: ReassignTaskRequest(task: .init(assignee_id: assigneeId)))
    }
}
