import SwiftUI
import AVKit

struct PlayerView: View {
    let movie: Movie
    let detail: VideoDetail?

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var loading = true
    @State private var error: String?
    @State private var streamURL: URL?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline).foregroundColor(.white)
                            .padding(10)
                    }
                    Spacer()
                    Text(movie.displayNumber)
                        .font(.headline).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 8)

                if let p = player {
                    VideoPlayer(player: p)
                } else if loading {
                    VStack(spacing: 12) {
                        ProgressView().colorInvert()
                        Text("正在获取播放源…").foregroundColor(.white.opacity(0.8))
                    }
                } else if let e = error {
                    VStack(spacing: 12) {
                        Image(systemName: "play.slash").font(.largeTitle).foregroundColor(.white.opacity(0.6))
                        Text(e).foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        Text("在线播放需要服务器配置 JAVDB VIP 或本地影库。")
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                    .padding(30)
                }
                Spacer()
            }
        }
        .task { await resolveStream() }
        .onDisappear { player?.pause() }
    }

    private func resolveStream() async {
        loading = true
        error = nil
        do {
            let url = try await fetchStreamURL()
            if let url {
                streamURL = url
                let item = AVPlayerItem(url: url)
                let p = AVPlayer(playerItem: item)
                p.play()
                player = p
            } else {
                error = "未找到可用的播放源"
            }
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }

    private func fetchStreamURL() async throws -> URL? {
        let videoID = detail?.videoID ?? movie.id
        // 1) Online play episodes (VIP)
        if movie.canPlay == true {
            let ep = try await JavDBSDK.onlinePlayEpisodes(videoID: videoID, sourceID: "online")
            if let u = JSONObject.findURL(in: ep.raw) { return URL(string: u) }
        }
        // 2) Local library stream
        let lib = try await JavDBSDK.libraryStream(id: videoID)
        if let u = JSONObject.findURL(in: lib.raw) { return URL(string: u) }
        return nil
    }
}

extension JSONObject {
    /// Recursively search a decoded JSON object for the first string that looks
    /// like a playable stream URL (hls / mp4 / m3u8 / http media).
    static func findURL(in object: Any, depth: Int = 0) -> String? {
        guard depth < 6 else { return nil }
        if let s = object as? String {
            let t = s.lowercased()
            if (t.contains(".m3u8") || t.contains(".mp4") || t.contains(".ts") ||
                t.contains(".mkv") || t.contains(".webm") || t.contains(".mov")) &&
                (s.hasPrefix("http://") || s.hasPrefix("https://") || s.hasPrefix("rtsp://") || s.hasPrefix("rtmp://")) {
                return s
            }
            return nil
        }
        if let arr = object as? [Any] {
            for item in arr {
                if let u = findURL(in: item, depth: depth + 1) { return u }
            }
            return nil
        }
        if let dict = object as? [String: Any] {
            // prefer keys that clearly denote a stream
            let preferred = ["url", "play_url", "stream_url", "hls", "m3u8", "src", "video_url", "playUrl"]
            for key in preferred {
                if let u = findURL(in: dict[key] as Any, depth: depth + 1) { return u }
            }
            for (_, value) in dict {
                if let u = findURL(in: value, depth: depth + 1) { return u }
            }
        }
        return nil
    }
}
