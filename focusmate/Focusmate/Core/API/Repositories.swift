import Foundation

final class ListsRepo {
    private let api: NewAPIClient
    init(api: NewAPIClient) { self.api = api }

    func index(cursor: String? = nil) async throws -> Page<ListDTO> {
        try await api.request("GET", API.Lists.root, query: cursor.map { [URLQueryItem(name:"cursor", value:$0)] })
    }
    
    func create(title: String, visibility: String = "private") async throws -> ListDTO {
        try await api.request("POST", API.Lists.root,
                              body: CreateListRequest(list: .init(title: title, visibility: visibility)),
                              idempotencyKey: UUID().uuidString)
    }
    
    func update(id: String, title: String? = nil, visibility: String? = nil) async throws -> ListDTO {
        try await api.request("PATCH", API.Lists.id(id),
                              body: UpdateListRequest(list: .init(title: title, visibility: visibility)))
    }
    
    func destroy(id: String) async throws {
        _ = try await api.request("DELETE", API.Lists.id(id)) as Empty
    }
}

final class TasksRepo {
    private let api: NewAPIClient
    init(api: NewAPIClient) { self.api = api }

    func index(listId: String, cursor: String? = nil) async throws -> Page<TaskDTO> {
        try await api.request("GET", API.Lists.tasks(listId),
                              query: cursor.map { [URLQueryItem(name:"cursor", value:$0)] })
    }
    
    func create(listId: String, title: String, notes: String? = nil, visibility: String = "private") async throws -> TaskDTO {
        try await api.request("POST", API.Lists.tasks(listId),
            body: CreateTaskRequest(task: .init(title: title, notes: notes, visibility: visibility)),
            idempotencyKey: UUID().uuidString)
    }
    
    func update(listId: String, id: String, title: String? = nil, notes: String? = nil, visibility: String? = nil) async throws -> TaskDTO {
        try await api.request("PATCH", API.Lists.task(listId, id), 
                              body: UpdateTaskRequest(task: .init(title: title, notes: notes, visibility: visibility)))
    }
    
    func destroy(listId: String, id: String) async throws {
        _ = try await api.request("DELETE", API.Lists.task(listId, id)) as Empty
    }
    
    func complete(listId: String, id: String, done: Bool) async throws -> TaskDTO {
        let path = API.Lists.taskAction(listId, id, done ? "complete" : "uncomplete")
        return try await api.request("PATCH", path)
    }
    
    func reassign(listId: String, id: String, assigneeId: String) async throws -> TaskDTO {
        try await api.request("PATCH", API.Lists.taskAction(listId, id, "reassign"),
                              body: ReassignTaskRequest(task: .init(assignee_id: assigneeId)))
    }
}
