import Foundation

enum APIError: Error {
    case badURL
    case badStatus(Int)
    case decoding
    case unauthorized
    case network(Error)
}


