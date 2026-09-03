import Foundation

/// Typed accessors over the DB Online HTTP API.
/// All endpoints live under `/api` and use the `{success,data,message,error}` envelope.
enum JavDBSDK {

    // MARK: Auth

    static func login(password: String) async throws -> String? {
        struct Body: Encodable { let password: String }
        let d = try await APIClient.shared.post("/auth/login", body: Body(password: password), as: JSONObject.self)
        if let t = d.raw["token"] as? String { return t }
        if let t = d.raw["access_token"] as? String { return t }
        if let t = d.raw["accessToken"] as? String { return t }
        return nil
    }

    static func logout() async throws -> Empty {
        try await APIClient.shared.post("/auth/logout", as: Empty.self)
    }

    static func authStatus() async throws -> [String: Any] {
        try await APIClient.shared.get("/auth/status", as: JSONObject.self).raw
    }

    // MARK: Content

    static func latest(page: Int = 1, limit: Int = 24, type: String = "all",
                       sortBy: String = "update", filterBy: String = "magnets") async throws -> MoviePage {
        try await APIClient.shared.get("/latest", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "limit", value: "\(limit)"),
            .init(name: "type", value: type),
            .init(name: "sort_by", value: sortBy),
            .init(name: "filter_by", value: filterBy)
        ], as: MoviePage.self)
    }

    static func recommend(page: Int = 1, limit: Int = 20) async throws -> MoviePage {
        try await APIClient.shared.get("/recommend", query: [
            .init(name: "page", value: "\(page)"),
            .init(name: "limit", value: "\(limit)")
        ], as: MoviePage.self)
    }

    static func rankings(period: String = "daily", type: Int = 0) async throws -> RankingPage {
        try await APIClient.shared.get("/rankings", query: [
            .init(name: "period", value: period),
            .init(name: "type", value: "\(type)")
        ], as: RankingPage.self)
    }

    static func top250(type: String = "all", typeValue: String = "",
                       ignoreWatched: Bool = false, startRank: Int = 1,
                       page: Int = 1, limit: Int = 25) async throws -> MoviePage {
        try await APIClient.shared.get("/top250", query: [
            .init(name: "type", value: type),
            .init(name: "type_value", value: typeValue),
            .init(name: "ignore_watched", value: ignoreWatched ? "true" : "false"),
            .init(name: "start_rank", value: "\(startRank)"),
            .init(name: "page", value: "\(page)"),
            .init(name: "limit", value: "\(limit)")
        ], as: MoviePage.self)
    }

    static func search(q: String, type: String = "movie", movieType: String = "all",
                       sortBy: String = "relevance", filterBy: String = "all",
                       page: Int = 1, limit: Int = 24) async throws -> MoviePage {
        try await APIClient.shared.get("/search", query: [
            .init(name: "q", value: q),
            .init(name: "type", value: type),
            .init(name: "movie_type", value: movieType),
            .init(name: "movie_sort_by", value: sortBy),
            .init(name: "movie_filter_by", value: filterBy),
            .init(name: "page", value: "\(page)"),
            .init(name: "limit", value: "\(limit)")
        ], as: MoviePage.self)
    }

    static func searchActors(q: String) async throws -> ActorPage {
        try await APIClient.shared.get("/search/actors", query: [.init(name: "q", value: q)], as: ActorPage.self)
    }

    static func videoDetail(id: String, refresh: Bool = false) async throws -> VideoDetail {
        try await APIClient.shared.get("/video/id/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
                                       query: refresh ? [.init(name: "refresh", value: "true")] : nil,
                                       as: VideoDetail.self)
    }

    static func magnets(id: String) async throws -> MagnetsResult {
        try await APIClient.shared.get("/external-magnets/custom/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
                                       as: MagnetsResult.self)
    }

    static func nyaaMagnets(id: String) async throws -> MagnetsResult {
        try await APIClient.shared.get("/external-magnets/nyaa/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
                                       as: MagnetsResult.self)
    }

    // MARK: People

    static func actors(type: Int = 0) async throws -> ActorPage {
        try await APIClient.shared.get("/actors", query: [.init(name: "type", value: "\(type)")], as: ActorPage.self)
    }

    static func personMovies(_ path: String, id: String) async throws -> MoviePage {
        try await APIClient.shared.get("/\(path)/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)/movies",
                                       as: MoviePage.self)
    }

    // MARK: Lists

    static func listsRelated() async throws -> JSONObject {
        try await APIClient.shared.get("/lists/related", as: JSONObject.self)
    }

    // MARK: Playback

    static func onlinePlayEpisodes(videoID: String, sourceID: String, videoRef: String? = nil) async throws -> JSONObject {
        var q = [URLQueryItem(name: "source_id", value: sourceID)]
        if let v = videoRef { q.append(.init(name: "video_id", value: v)) }
        return try await APIClient.shared.get("/video/\(videoID)/online-play/episodes", query: q, as: JSONObject.self)
    }

    static func libraryStream(id: String) async throws -> JSONObject {
        try await APIClient.shared.get("/library/stream/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)",
                                       as: JSONObject.self)
    }

    // MARK: Subtitles

    static func findSubtitle(id: String) async throws -> [SubtitleItem] {
        struct Wrapper: Decodable { let subtitles: [SubtitleItem]? }
        if let w = try? await APIClient.shared.get("/subtitle/find/\(id)", as: Wrapper.self) {
            return w.subtitles ?? []
        }
        return []
    }

    // MARK: Subscriptions

    static func subscriptions() async throws -> JSONObject {
        try await APIClient.shared.get("/subs", as: JSONObject.self)
    }

    static func followingUsers() async throws -> JSONObject {
        try await APIClient.shared.get("/following/users", as: JSONObject.self)
    }

    static func subscriptionVideos() async throws -> JSONObject {
        try await APIClient.shared.get("/subscription-videos", as: JSONObject.self)
    }

    // MARK: Downloads

    static func downloaders() async throws -> [Downloader] {
        struct W: Decodable { let downloaders: [Downloader]? }
        if let w = try? await APIClient.shared.get("/downloaders", as: W.self) {
            return w.downloaders ?? []
        }
        return []
    }

    static func downloadRecords() async throws -> JSONObject {
        try await APIClient.shared.get("/download-records", as: JSONObject.self)
    }

    static func qbittorrentTasks() async throws -> JSONObject {
        try await APIClient.shared.get("/qbittorrent/tasks", as: JSONObject.self)
    }

    static func aria2Tasks() async throws -> JSONObject {
        try await APIClient.shared.get("/aria2/tasks", as: JSONObject.self)
    }

    static func pan115Tasks() async throws -> JSONObject {
        try await APIClient.shared.get("/pan115/tasks", as: JSONObject.self)
    }

    static func thunderTasks() async throws -> JSONObject {
        try await APIClient.shared.get("/thunder/tasks", as: JSONObject.self)
    }

    // MARK: System

    static func health() async throws -> HealthStatus {
        try await APIClient.shared.get("/health", as: HealthStatus.self)
    }

    static func version() async throws -> VersionInfo {
        try await APIClient.shared.get("/version", as: VersionInfo.self)
    }

    static func loginCovers(limit: Int = 36) async throws -> LoginCoversPage {
        try await APIClient.shared.get("/login/covers", query: [.init(name: "limit", value: "\(limit)")],
                                       as: LoginCoversPage.self)
    }

    // MARK: Admin (setup / logs / JAVDB account)

    static func logs() async throws -> JSONObject {
        try await APIClient.shared.get("/logs", as: JSONObject.self)
    }

    static func setupStatus() async throws -> JSONObject {
        try await APIClient.shared.get("/setup/status", as: JSONObject.self)
    }

    static func setupTestConnection(_ db: [String: Any]) async throws -> JSONObject {
        try await APIClient.shared.postRawJSON("/setup/test-connection", body: db, as: JSONObject.self)
    }

    static func setupListDatabases(_ db: [String: Any]) async throws -> JSONObject {
        try await APIClient.shared.postRawJSON("/setup/list-databases", body: db, as: JSONObject.self)
    }

    static func setupCreateDatabase(_ db: [String: Any]) async throws -> JSONObject {
        try await APIClient.shared.postRawJSON("/setup/create-database", body: db, as: JSONObject.self)
    }

    static func setupInitialize(_ db: [String: Any]) async throws -> JSONObject {
        try await APIClient.shared.postRawJSON("/setup/initialize", body: db, as: JSONObject.self)
    }

    static func setupRestart() async throws -> JSONObject {
        try await APIClient.shared.postRawJSON("/setup/restart", body: [:], as: JSONObject.self)
    }

    static func javdbLogin(username: String, password: String) async throws -> JSONObject {
        try await APIClient.shared.postRawJSON("/get-token",
                                               body: ["username": username, "password": password],
                                               as: JSONObject.self)
    }

    static func javdbUserInfo(refresh: Bool = false) async throws -> JSONObject {
        let q = refresh ? [URLQueryItem(name: "refresh", value: "true")] : nil
        return try await APIClient.shared.get("/javdb/user", query: q, as: JSONObject.self)
    }
}

/// Minimal dynamic JSON wrapper for endpoints whose shape is not strictly typed.
struct JSONObject: Decodable {
    let raw: [String: Any]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            raw = dict.mapValues { $0.value }
        } else {
            raw = [:]
        }
    }
}

struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { value = b }
        else if let i = try? c.decode(Int.self) { value = i }
        else if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = s }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map { $0.value } }
        else if let o = try? c.decode([String: AnyCodable].self) { value = o.mapValues { $0.value } }
        else { value = NSNull() }
    }
}
