import Foundation

enum NetworkingError: Error, Equatable {
    case invalidContentType(expected: [String], actual: String?)
    case invalidEncoding
    case invalidURL(String)
}
