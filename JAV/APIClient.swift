import Foundation

/// Configuration persisted across launches.
final class AppConfig: ObservableObject {
    static let shared = AppConfig()

    @Published var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: "serverBaseURL") }
    }
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "serverAPIKey") }
    }

    init() {
        baseURL = UserDefaults.standard.string(forKey: "serverBaseURL") ?? ""
        apiKey = UserDefaults.standard.string(forKey: "serverAPIKey") ?? ""
    }

    var normalizedBaseURL: String {
        var s = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }
}

/// A single API client. Decodes the `{success,data,message,error}` envelope.
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private(set) var authToken: String?

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 120
        cfg.httpAdditionalHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
        session = URLSession(configuration: cfg)
    }

    // MARK: Auth token

    func setAuthToken(_ token: String?) {
        authToken = token
        if let t = token {
            UserDefaults.standard.set(t, forKey: "authToken")
        } else {
            UserDefaults.standard.removeObject(forKey: "authToken")
        }
    }

    func loadAuthToken() {
        authToken = UserDefaults.standard.string(forKey: "authToken")
    }

    // MARK: URL construction

    func url(_ path: String, query: [URLQueryItem]? = nil) throws -> URL {
        let base = AppConfig.shared.normalizedBaseURL
        guard !base.isEmpty else {
            throw APIError.notConfigured
        }
        var comps = URLComponents(string: base + "/api" + path)
        if let q = query, !q.isEmpty {
            comps?.queryItems = q
        }
        guard let u = comps?.url else {
            throw APIError.invalidURL
        }
        return u
    }

    /// Builds the absolute URL for an image proxy path. Handles both
    /// `/api/image?url=...` (already proxied) and raw absolute URLs.
    static func resolveImageURL(_ path: String?) -> URL? {
        guard let p = path, !p.isEmpty else { return nil }
        if p.hasPrefix("http://") || p.hasPrefix("https://") {
            return URL(string: p)
        }
        let base = AppConfig.shared.normalizedBaseURL
        guard !base.isEmpty else { return nil }
        if p.hasPrefix("/") {
            return URL(string: base + p)
        }
        return URL(string: base + "/" + p)
    }

    // MARK: Requests

    func get<T: Decodable>(_ path: String, query: [URLQueryItem]? = nil, as type: T.Type) async throws -> T {
        return try await request(method: "GET", path: path, query: query, body: Optional<Empty>.none, as: type)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        return try await request(method: "POST", path: path, query: nil, body: body, as: type)
    }

    func post<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        return try await request(method: "POST", path: path, query: nil, body: Optional<Int>.none, as: type)
    }

    func put<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        return try await request(method: "PUT", path: path, query: nil, body: body, as: type)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B, as type: T.Type) async throws -> T {
        return try await request(method: "PATCH", path: path, query: nil, body: body, as: type)
    }

    func delete<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        return try await request(method: "DELETE", path: path, query: nil, body: Optional<Int>.none, as: type)
    }

    // MARK: Core request

    private func request<T: Decodable, B: Encodable>(method: String, path: String,
                                                     query: [URLQueryItem]?, body: B?,
                                                     as type: T.Type) async throws -> T {
        let u = try url(path, query: query)
        var req = URLRequest(url: u)
        req.httpMethod = method
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let apiKey = AppConfig.shared.apiKey
        if !apiKey.isEmpty {
            req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: (resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        if !decoded.success {
            throw APIError.api(message: decoded.error ?? decoded.message ?? "请求失败")
        }
        guard let d = decoded.data else {
            if T.self == Empty.self {
                return Empty() as! T
            }
            throw APIError.api(message: "响应缺少数据")
        }
        return d
    }

    /// PUTs a raw JSON dictionary (for config updates) and decodes the envelope.
    func putRawJSON<T: Decodable>(_ path: String, body: [String: Any], as type: T.Type) async throws -> T {
        let u = try url(path)
        var req = URLRequest(url: u)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let apiKey = AppConfig.shared.apiKey
        if !apiKey.isEmpty {
            req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: (resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        if !decoded.success {
            throw APIError.api(message: decoded.error ?? decoded.message ?? "请求失败")
        }
        guard let d = decoded.data else {
            throw APIError.api(message: "响应缺少数据")
        }
        return d
    }

    /// POSTs a raw JSON dictionary (for setup / login actions) and decodes the envelope.
    func postRawJSON<T: Decodable>(_ path: String, body: [String: Any], as type: T.Type) async throws -> T {
        let u = try url(path)
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let apiKey = AppConfig.shared.apiKey
        if !apiKey.isEmpty {
            req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 401 {
            throw APIError.unauthorized
        }
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.server(status: (resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let decoded = try JSONDecoder().decode(APIResponse<T>.self, from: data)
        if !decoded.success {
            throw APIError.api(message: decoded.error ?? decoded.message ?? "请求失败")
        }
        guard let d = decoded.data else {
            throw APIError.api(message: "响应缺少数据")
        }
        return d
    }

    /// Fetches raw data (for subtitles / downloads) without envelope parsing.
    func rawData(_ path: String, query: [URLQueryItem]? = nil) async throws -> Data {
        let u = try url(path, query: query)
        var req = URLRequest(url: u)
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let apiKey = AppConfig.shared.apiKey
        if !apiKey.isEmpty {
            req.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.server(status: http.statusCode)
        }
        return data
    }
}

struct Empty: Codable {}

enum APIError: LocalizedError {
    case notConfigured
    case invalidURL
    case unauthorized
    case server(status: Int)
    case api(message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先在设置中填写服务器地址"
        case .invalidURL: return "服务器地址无效"
        case .unauthorized: return "登录已失效，请重新登录"
        case .server(let s): return "服务器错误（\(s)）"
        case .api(let m): return m
        }
    }
}
