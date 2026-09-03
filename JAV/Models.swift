import Foundation

// MARK: - Flexible primitive decoders

/// Decodes a value that may be presented either as a number or as a string.
enum DoubleString: Codable, Equatable, Hashable {
    case double(Double)
    case string(String)

    var value: Double? {
        switch self {
        case .double(let d): return d
        case .string(let s): return Double(s)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.typeMismatch(DoubleString.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Expected number or string"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        }
    }
}

/// Decodes a value that may be a string or a boolean (some endpoints emit `"1"/"0"`).
enum FlexibleBool: Codable, Equatable, Hashable {
    case bool(Bool)
    case string(String)

    var value: Bool {
        switch self {
        case .bool(let b): return b
        case .string(let s): return s == "1" || s == "true" || s == "yes"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else {
            throw DecodingError.typeMismatch(FlexibleBool.self,
                DecodingError.Context(codingPath: decoder.codingPath,
                                      debugDescription: "Expected bool or string"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .bool(let b): try c.encode(b)
        case .string(let s): try c.encode(s)
        }
    }
}

// MARK: - API envelope

struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
    let error: String?
}

// MARK: - Library presence

struct LibraryState: Codable, Hashable {
    let inLibrary: Bool
    enum CodingKeys: String, CodingKey { case inLibrary = "in_library" }
}

// MARK: - Movie

struct Movie: Identifiable, Codable, Hashable {
    let id: String
    let number: String?
    let title: String?
    let originTitle: String?
    let coverURL: String?
    let thumbURL: String?
    let duration: Int?
    let score: DoubleString?
    let releaseDate: String?
    let canPlay: Bool?
    let hasCnsub: Bool?
    let hasPreviewImages: Bool?
    let hasPreviewVideo: Bool?
    let magnetsCount: Int?
    let newMagnets: Bool?
    let playSubtitle: Int?
    let ranking: Int?
    let watchedCount: Int?
    let library: LibraryState?
    let previewImages: [PreviewImage]?

    var displayNumber: String { number ?? id }
    var displayTitle: String {
        let t = title ?? ""
        if !t.isEmpty { return t }
        return originTitle ?? displayNumber
    }
    var scoreValue: Double? { score?.value }

    enum CodingKeys: String, CodingKey {
        case id, number, title, duration, score, ranking
        case originTitle = "origin_title"
        case coverURL = "cover_url"
        case thumbURL = "thumb_url"
        case releaseDate = "release_date"
        case canPlay = "can_play"
        case hasCnsub = "has_cnsub"
        case hasPreviewImages = "has_preview_images"
        case hasPreviewVideo = "has_preview_video"
        case magnetsCount = "magnets_count"
        case newMagnets = "new_magnets"
        case playSubtitle = "play_subtitle"
        case watchedCount = "watched_count"
        case library
        case previewImages = "preview_images"
    }
}

struct PreviewImage: Codable, Hashable {
    let largeURL: String?
    let thumbURL: String?
    enum CodingKeys: String, CodingKey {
        case largeURL = "large_url"
        case thumbURL = "thumb_url"
    }
}

// MARK: - Person (actor / director / maker / publisher / series)

struct Person: Identifiable, Codable, Hashable {
    let id: String
    let externalID: String?
    let name: String?
    let nameZht: String?
    let otherName: String?
    let gender: String?
    let type: Int?
    let uncensored: Bool?
    let videosCount: Int?
    let avatarURL: String?

    var displayName: String { name ?? externalID ?? id }

    enum CodingKeys: String, CodingKey {
        case id, name, gender, type, uncensored
        case externalID = "external_id"
        case nameZht = "name_zht"
        case otherName = "other_name"
        case videosCount = "videos_count"
        case avatarURL = "avatar_url"
    }
}

// MARK: - Category

struct Category: Identifiable, Codable, Hashable {
    let id: String
    let externalID: String?
    let name: String?
    var displayName: String { name ?? id }
    enum CodingKeys: String, CodingKey {
        case id, name
        case externalID = "external_id"
    }
}

// MARK: - Relative movie

struct RelativeMovie: Identifiable, Codable, Hashable {
    let id: String
    let number: String?
    let thumbURL: String?
    let library: LibraryState?
    enum CodingKeys: String, CodingKey {
        case id, number
        case thumbURL = "thumb_url"
        case library
    }
}

// MARK: - Video detail

struct VideoDetail: Codable {
    let code: String?
    let title: String?
    let videoID: String?
    let coverURL: String?
    let thumbURL: String?
    let previews: [String]?
    let date: String?
    let duration: Int?
    let director: Person?
    let maker: Person?
    let publisher: Person?
    let series: Person?
    let score: Double?
    let watchedCount: Int?
    let categories: [Category]?
    let actors: [Person]?
    let relativeMovies: [RelativeMovie]?

    enum CodingKeys: String, CodingKey {
        case code, title, date, duration, director, maker, publisher, series, score, categories, actors
        case videoID = "video_id"
        case coverURL = "cover_url"
        case thumbURL = "thumb_url"
        case previews
        case watchedCount = "watched_count"
        case relativeMovies = "relative_movies"
    }
}

// MARK: - Magnet

struct Magnet: Identifiable, Codable, Hashable {
    let id: String
    let number: String?
    let title: String?
    let size: String?
    let date: String?
    let shareDate: String?
    let url: String?
    let link: String?
    let magnetLink: String?
    let hash: String?
    let meta: [String: String]?

    var displayTitle: String { title ?? number ?? id }
    var displaySize: String { size ?? "" }
    var displayDate: String { date ?? shareDate ?? "" }
    var magnetURL: String? { magnetLink ?? link ?? url }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id))
            ?? (try? c.decode(String.self, forKey: .number))
            ?? (try? c.decode(String.self, forKey: .hash))
            ?? UUID().uuidString
        number = try? c.decode(String.self, forKey: .number)
        title = try? c.decode(String.self, forKey: .title)
        size = try? c.decode(String.self, forKey: .size)
        date = try? c.decode(String.self, forKey: .date)
        shareDate = try? c.decode(String.self, forKey: .shareDate)
        url = try? c.decode(String.self, forKey: .url)
        link = try? c.decode(String.self, forKey: .link)
        magnetLink = try? c.decode(String.self, forKey: .magnetLink)
        hash = try? c.decode(String.self, forKey: .hash)
        meta = try? c.decode([String: String].self, forKey: .meta)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(number, forKey: .number)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(size, forKey: .size)
        try c.encodeIfPresent(date, forKey: .date)
        try c.encodeIfPresent(shareDate, forKey: .shareDate)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(link, forKey: .link)
        try c.encodeIfPresent(magnetLink, forKey: .magnetLink)
        try c.encodeIfPresent(hash, forKey: .hash)
        try c.encodeIfPresent(meta, forKey: .meta)
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, size, date, url, link, hash, meta
        case shareDate = "share_date"
        case magnetLink = "magnet_link"
    }
}

struct MagnetsResult: Codable {
    let code: String?
    let count: Int?
    let ed2ks: [String]?
    let magnets: [Magnet]?
    let source: String?
}

// MARK: - List pages

struct MoviePage: Codable {
    let movies: [Movie]?
    let total: Int?
    let page: Int?
    let limit: Int?
}

struct RankingPage: Codable {
    let period: String?
    let movies: [Movie]?
}

struct ActorPage: Codable {
    let actors: [Person]?
}

// MARK: - Downloader

struct Downloader: Identifiable, Codable {
    var id: String { key ?? UUID().uuidString }
    let key: String?
    let name: String?
    let enabled: Bool?
    let type: String?
    let configured: Bool?

    enum CodingKeys: String, CodingKey {
        case key, name, enabled, type, configured
    }
}

struct DownloadTask: Identifiable, Codable {
    var id: String { hash ?? UUID().uuidString }
    let hash: String?
    let name: String?
    let size: String?
    let progress: Double?
    let state: String?
    let speed: String?
    let downloader: String?

    var progressValue: Double {
        if let p = progress, p <= 1 { return p }
        return 0
    }
}

// MARK: - Subscription

struct Subscription: Identifiable, Codable {
    var id: String { key ?? name ?? UUID().uuidString }
    let key: String?
    let name: String?
    let type: String?
    let enabled: Bool?
    let total: Int?
    let newCount: Int?

    enum CodingKeys: String, CodingKey {
        case key, name, type, enabled, total
        case newCount = "new_count"
    }
}

// MARK: - Subtitle

struct SubtitleItem: Identifiable, Codable {
    let id: String?
    let name: String?
    let language: String?
    let seller: String?
    let downloadURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, language, seller
        case downloadURL = "download_url"
    }
}

// MARK: - System

struct HealthStatus: Codable {
    let status: String?
    let timestamp: String?
    let mode: String?
}

struct VersionInfo: Codable {
    let projectName: String?
    let version: String?
    let buildTime: String?
    let gitCommit: String?

    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case version
        case buildTime = "build_time"
        case gitCommit = "git_commit"
    }
}

struct LoginCoversPage: Codable {
    let covers: [String]?
    let images: [String]?
}
