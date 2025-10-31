import Foundation

/// Protocol for networking operations to abstract away raw URLSession usage
protocol NetworkingProtocol {
  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)?,
    queryParameters: [String: String]
  ) async throws -> T

  func getRawResponse(endpoint: String, params: [String: String]) async throws -> Data
}

/// Internal networking implementation that handles raw URLSession calls
/// This is the only place where raw networking should occur
final class InternalNetworking: NetworkingProtocol {
  private let session: URLSession = .shared
  private let tokenProvider: () -> String?

  init(tokenProvider: @escaping () -> String?) {
    self.tokenProvider = tokenProvider
  }

  func request<T: Decodable>(
    _ method: String,
    _ path: String,
    body: (some Encodable)? = nil,
    queryParameters: [String: String] = [:]
  ) async throws -> T {
    var url = Endpoints.path(path)

    // Add query parameters
    if !queryParameters.isEmpty {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
      if let newURL = components?.url {
        url = newURL
      }
    }

    var req = URLRequest(url: url)
    req.httpMethod = method
    if let b = body {
      req.httpBody = try APIClient.encoder.encode(b)
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("ngrok-skip-browser-warning", forHTTPHeaderField: "ngrok-skip-browser-warning")

    if let jwt = tokenProvider() {
      req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
    }

    let (data, resp) = try await session.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }

    // Parse error response if present
    let errorResponse = self.parseErrorResponse(data: data, statusCode: http.statusCode)

    switch http.statusCode {
    case 200 ... 299:
      break
    case 401:
      print("🚫 APIClient: 401 Unauthorized for \(method) \(url.absoluteString)")
      throw APIError.unauthorized
    case 429:
      let retryAfter = self.extractRetryAfter(from: http.allHeaderFields)
      print("⏰ APIClient: 429 Rate Limited for \(method) \(url.absoluteString), retry after: \(retryAfter)s")
      throw APIError.rateLimited(retryAfter)
    case 500 ... 599:
      print("🔥 APIClient: Server error \(http.statusCode) for \(method) \(url.absoluteString)")
      throw APIError.serverError(http.statusCode, errorResponse?.message, errorResponse?.details)
    default:
      let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
      print("⚠️ APIClient: bad status \(http.statusCode) for \(method) \(url.absoluteString) body=\(bodyPreview)")
      throw APIError.badStatus(http.statusCode, errorResponse?.message, errorResponse?.details)
    }

    do {
      // Handle empty responses (common for DELETE requests)
      if data.isEmpty {
        if T.self == EmptyResponse.self {
          return EmptyResponse() as! T
        } else {
          print("🧩 APIClient: Expected \(T.self) but got empty response")
          throw APIError.decoding
        }
      }

      let result = try APIClient.railsAPI.decode(T.self, from: data)
      return result
    } catch {
      let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
      print("🧩 APIClient: decoding error for \(method) \(url.absoluteString)")
      print("🧩 APIClient: Response body: \(bodyPreview)")
      print("🧩 APIClient: Decoding error: \(error)")
      throw APIError.decoding
    }
  }

  func getRawResponse(endpoint: String, params: [String: String] = [:]) async throws -> Data {
    var url = Endpoints.path(endpoint)

    // Add query parameters
    if !params.isEmpty {
      var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
      components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
      if let newURL = components?.url {
        url = newURL
      }
    }

    var req = URLRequest(url: url)
    req.httpMethod = "GET"
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    req.setValue("ngrok-skip-browser-warning", forHTTPHeaderField: "ngrok-skip-browser-warning")

    if let jwt = tokenProvider() {
      req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
    }

    let (data, resp) = try await session.data(for: req)
    guard let http = resp as? HTTPURLResponse else { throw APIError.badURL }

    switch http.statusCode {
    case 200 ... 299:
      return data
    case 401:
      throw APIError.unauthorized
    default:
      let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8>"
      print("⚠️ APIClient: bad status \(http.statusCode) for GET \(url.absoluteString) body=\(bodyPreview)")
      throw APIError.badStatus(http.statusCode, nil, nil)
    }
  }

  // MARK: - Error Response Parsing

  private func parseErrorResponse(data: Data, statusCode: Int) -> ErrorResponse? {
    guard !data.isEmpty, statusCode >= 400 else { return nil }

    do {
      let errorResponse = try APIClient.railsAPI.decode(ErrorResponse.self, from: data)
      return errorResponse
    } catch {
      // If we can't parse as structured error, try to extract basic info
      if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        let message = json["message"] as? String ?? json["error"] as? String
        let code = json["code"] as? String ?? "HTTP_\(statusCode)"

        return ErrorResponse(
          code: code,
          message: message ?? "HTTP \(statusCode) error",
          details: nil,
          timestamp: json["timestamp"] as? String,
          status: statusCode,
          requestId: json["request_id"] as? String
        )
      }
      return nil
    }
  }

  private func extractRetryAfter(from headers: [AnyHashable: Any]) -> Int {
    if let retryAfter = headers["Retry-After"] as? String,
       let seconds = Int(retryAfter)
    {
      return seconds
    }
    return 60 // Default retry after 60 seconds
  }
}
