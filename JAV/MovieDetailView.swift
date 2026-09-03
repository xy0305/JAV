import SwiftUI
import UIKit

struct MovieDetailView: View {
    let movie: Movie
    @State private var detail: VideoDetail?
    @State private var magnets: [Magnet] = []
    @State private var loading = true
    @State private var error: String?
    @State private var showPlayer = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if loading {
                    LoadingView().frame(height: 200)
                } else if let e = error {
                    ErrorStateView(message: e) { Task { await load() } }.frame(height: 200)
                } else if let d = detail {
                    detailSections(d)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .navigationTitle(movie.displayNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if movie.canPlay == true || detail != nil {
                    Button { showPlayer = true } label: { Image(systemName: "play.circle.fill") }
                }
            }
        }
        .task { await load() }
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(movie: movie, detail: detail)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            RemoteImage(url: movie.coverURL ?? movie.thumbURL)
                .frame(width: 130, height: 185)
                .cornerRadius(10)
                .clipped()
            VStack(alignment: .leading, spacing: 8) {
                Text(movie.displayNumber)
                    .font(.headline)
                    .foregroundColor(Theme.accent)
                Text(movie.displayTitle)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(4)
                if let s = movie.scoreValue {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundColor(Theme.scoreColor(s))
                        Text(String(format: "%.2f", s)).foregroundColor(Theme.scoreColor(s)).bold()
                    }
                }
                if let d = movie.duration {
                    Label("\(d) 分钟", systemImage: "clock")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
                if let r = movie.releaseDate {
                    Label(r, systemImage: "calendar")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
                if let w = movie.watchedCount {
                    Label("\(w) 次浏览", systemImage: "eye")
                        .font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Detail sections

    @ViewBuilder
    private func detailSections(_ d: VideoDetail) -> some View {
        // previews
        if let previews = d.previews, !previews.isEmpty {
            section("剧照") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(previews.enumerated()), id: \.offset) { _, p in
                            RemoteImage(url: p)
                                .frame(width: 220, height: 130)
                                .cornerRadius(8)
                                .clipped()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        // actors
        if let actors = d.actors, !actors.isEmpty {
            section("演员") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(actors) { a in
                            NavigationLink(value: a) {
                                VStack(spacing: 6) {
                                    RemoteImage(url: a.avatarURL)
                                        .frame(width: 64, height: 64)
                                        .clipShape(Circle())
                                    Text(a.displayName)
                                        .font(.caption)
                                        .foregroundColor(Theme.textPrimary)
                                        .lineLimit(1)
                                }
                                .frame(width: 72)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }

        // info
        section("信息") {
            VStack(spacing: 8) {
                if let dir = d.director { KeyValueRow(key: "导演", value: dir.displayName) }
                if let mk = d.maker { KeyValueRow(key: "片商", value: mk.displayName) }
                if let pb = d.publisher { KeyValueRow(key: "发行商", value: pb.displayName) }
                if let sr = d.series { KeyValueRow(key: "系列", value: sr.displayName) }
                if let cats = d.categories, !cats.isEmpty {
                    KeyValueRow(key: "分类", value: cats.map { $0.displayName }.joined(separator: " · "))
                }
                if let dt = d.date { KeyValueRow(key: "发行日期", value: dt) }
                if let dur = d.duration { KeyValueRow(key: "时长", value: "\(dur) 分钟") }
                if let w = d.watchedCount { KeyValueRow(key: "浏览", value: "\(w)") }
            }
            .padding(.horizontal, 16)
        }

        // magnets
        if !magnets.isEmpty {
            section("磁力链接") {
                VStack(spacing: 8) {
                    ForEach(magnets) { m in
                        MagnetRow(magnet: m)
                    }
                }
                .padding(.horizontal, 16)
            }
        }

        // related
        if let rel = d.relativeMovies, !rel.isEmpty {
            section("相似推荐") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(rel) { r in
                            NavigationLink(value: Movie(id: r.id, number: r.number, title: nil,
                                                        originTitle: nil, coverURL: nil,
                                                        thumbURL: r.thumbURL, duration: nil, score: nil,
                                                        releaseDate: nil, canPlay: nil, hasCnsub: nil,
                                                        hasPreviewImages: nil, hasPreviewVideo: nil,
                                                        magnetsCount: nil, newMagnets: nil, playSubtitle: nil,
                                                        ranking: nil, watchedCount: nil, library: r.library,
                                                        previewImages: nil)) {
                                VStack(spacing: 4) {
                                    RemoteImage(url: r.thumbURL)
                                        .frame(width: 110, height: 152)
                                        .cornerRadius(8).clipped()
                                    Text(r.number ?? r.id)
                                        .font(.caption2.bold()).foregroundColor(Theme.textPrimary).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.horizontal, 16)
            content()
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            detail = try await JavDBSDK.videoDetail(id: movie.id)
            if let m = try? await JavDBSDK.magnets(id: movie.id) {
                magnets = m.magnets ?? []
            }
        } catch let err {
            error = err.localizedDescription
        }
        loading = false
    }
}

// MARK: - Magnet row

struct MagnetRow: View {
    let magnet: Magnet
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(magnet.displayTitle)
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    if !magnet.displaySize.isEmpty {
                        Text(magnet.displaySize).font(.caption2).foregroundColor(Theme.textSecondary)
                    }
                    if !magnet.displayDate.isEmpty {
                        Text(magnet.displayDate).font(.caption2).foregroundColor(Theme.textSecondary)
                    }
                }
            }
            Spacer()
            Button {
                copy()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundColor(copied ? .green : Theme.textSecondary)
            }
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(10)
    }

    private func copy() {
        let link = magnet.magnetURL ?? ""
        if !link.isEmpty {
            UIPasteboard.general.string = link
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
        }
    }
}
