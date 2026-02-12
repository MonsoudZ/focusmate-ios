import XCTest
@testable import focusmate

final class TagServiceTests: XCTestCase {

    private var mock: MockNetworking!
    private var service: TagService!

    override func setUp() {
        super.setUp()
        mock = MockNetworking()
        let apiClient = APIClient(tokenProvider: { nil }, networking: mock)
        service = TagService(apiClient: apiClient)
    }

    // MARK: - fetchTags

    func testFetchTagsDecodesResponse() async throws {
        let tag = TestFactories.makeSampleTag(id: 3, name: "Urgent")
        mock.stubJSON(TagsResponse(tags: [tag]))

        let result = try await service.fetchTags()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, 3)
        XCTAssertEqual(result.first?.name, "Urgent")
    }

    func testFetchTagsCallsCorrectEndpoint() async throws {
        mock.stubJSON(TagsResponse(tags: []))

        _ = try await service.fetchTags()

        XCTAssertEqual(mock.lastCall?.method, "GET")
        XCTAssertEqual(mock.lastCall?.path, API.Tags.root)
    }

    func testFetchTagsPropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            _ = try await service.fetchTags()
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }

    // MARK: - createTag

    func testCreateTagSendsCorrectBody() async throws {
        let tag = TestFactories.makeSampleTag(id: 10, name: "New")
        mock.stubJSON(tag)

        _ = try await service.createTag(name: "New", color: "#FF0000")

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Tags.root)

        let body = mock.lastBodyJSON
        let tagBody = body?["tag"] as? [String: Any]
        XCTAssertEqual(tagBody?["name"] as? String, "New")
        XCTAssertEqual(tagBody?["color"] as? String, "#FF0000")
    }

    func testCreateTagCallsCorrectEndpoint() async throws {
        mock.stubJSON(TestFactories.makeSampleTag())

        _ = try await service.createTag(name: "Tag", color: nil)

        XCTAssertEqual(mock.lastCall?.method, "POST")
        XCTAssertEqual(mock.lastCall?.path, API.Tags.root)
    }

    func testCreateTagWithNilColor() async throws {
        mock.stubJSON(TestFactories.makeSampleTag())

        _ = try await service.createTag(name: "Plain", color: nil)

        let body = mock.lastBodyJSON
        let tagBody = body?["tag"] as? [String: Any]
        XCTAssertEqual(tagBody?["name"] as? String, "Plain")
        // color key present but null in JSON
    }

    // MARK: - updateTag

    func testUpdateTagSendsCorrectBody() async throws {
        let tag = TestFactories.makeSampleTag(id: 5, name: "Updated")
        mock.stubJSON(tag)

        _ = try await service.updateTag(id: 5, name: "Updated", color: "#00FF00")

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Tags.id("5"))

        let body = mock.lastBodyJSON
        let tagBody = body?["tag"] as? [String: Any]
        XCTAssertEqual(tagBody?["name"] as? String, "Updated")
        XCTAssertEqual(tagBody?["color"] as? String, "#00FF00")
    }

    func testUpdateTagCallsCorrectEndpoint() async throws {
        mock.stubJSON(TestFactories.makeSampleTag())

        _ = try await service.updateTag(id: 12, name: nil, color: nil)

        XCTAssertEqual(mock.lastCall?.method, "PATCH")
        XCTAssertEqual(mock.lastCall?.path, API.Tags.id("12"))
    }

    // MARK: - deleteTag

    func testDeleteTagCallsCorrectEndpoint() async throws {
        try await service.deleteTag(id: 8)

        XCTAssertEqual(mock.lastCall?.method, "DELETE")
        XCTAssertEqual(mock.lastCall?.path, API.Tags.id("8"))
    }

    func testDeleteTagPropagatesError() async {
        mock.stubbedError = APIError.unauthorized(nil)

        do {
            try await service.deleteTag(id: 1)
            XCTFail("Expected error to be thrown")
        } catch {
            // Error propagated
        }
    }
}
