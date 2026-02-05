import Foundation

enum AppConfig {
    static var baseURL: URL {
    #if DEBUG
        URL(string: "http://Dr-Watson-Pro.local:8080")!
//        URL(string: "http://localhost:8080")!
    #else
        URL(string: "http://localhost:8080")!
    #endif
    }

    static var wsURL: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        components.path = "/v1/ws"
        return components.url!
    }

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
