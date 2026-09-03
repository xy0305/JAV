import SwiftUI

struct HomeView: View {
    enum Section: String, CaseIterable, Identifiable {
        case latest = "最新"
        case recommend = "推荐"
        case ranking = "排行"
        case top250 = "Top250"

        var id: String { rawValue }
    }

    @State private var section: Section = .latest

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    ForEach(Section.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                switch section {
                case .latest: LatestView()
                case .recommend: RecommendView()
                case .ranking: RankingView()
                case .top250: Top250View()
                }
            }
            .background(Theme.bg)
            .navigationTitle("DB Online")
            .appDestinations()
        }
    }
}

// MARK: - Latest

struct LatestView: View {
    @State private var movies: [Movie] = []
    @State private var page = 1
    @State private var loading = true
    @State private var error: String?
    @State private var type = "all"
    @State private var sortBy = "update"
    @State private var filterBy = "magnets"

    private let types = ["all": "全部", "censored": "有码", "uncensored": "无码"]
    private let sorts = ["update": "更新", "date": "发行", "rating": "评分"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("类型", selection: $type) {
                    ForEach(Array(types.keys.sorted()), id: \.self) { k in
                        Text(types[k] ?? k).tag(k)
                    }
                }
                Picker("排序", selection: $sortBy) {
                    ForEach(Array(sorts.keys.sorted()), id: \.self) { k in
                        Text(sorts[k] ?? k).tag(k)
                    }
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            content
        }
        .task(id: "\(type)-\(sortBy)-\(filterBy)") {
            await reload()
        }
    }

    @ViewBuilder private var content: some View {
        if loading && movies.isEmpty {
            LoadingView()
        } else if let e = error, movies.isEmpty {
            ErrorStateView(message: e) { Task { await reload() } }
        } else if movies.isEmpty {
            EmptyStateView(icon: "film", message: "暂无内容")
        } else {
            MovieGridView(movies: movies, onLoadMore: {
                Task { await loadMore() }
            })
        }
    }

    private func reload() async {
        loading = true
        error = nil
        page = 1
        do {
            let p = try await JavDBSDK.latest(page: 1, type: type, sortBy: sortBy, filterBy: filterBy)
            movies = p.movies ?? []
        } catch let err {
            error = err.localizedDescription
        }
        loading = false
    }

    private func loadMore() async {
        page += 1
        do {
            let p = try await JavDBSDK.latest(page: page, type: type, sortBy: sortBy, filterBy: filterBy)
            let new = p.movies ?? []
            if new.isEmpty { page -= 1 }
            movies.append(contentsOf: new)
        } catch {
            page -= 1
        }
    }
}

// MARK: - Recommend

struct RecommendView: View {
    @State private var movies: [Movie] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && movies.isEmpty {
                LoadingView()
            } else if let e = error, movies.isEmpty {
                ErrorStateView(message: e) { Task { await load() } }
            } else {
                MovieGridView(movies: movies, onLoadMore: nil)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let p = try await JavDBSDK.recommend(page: 1, limit: 40)
            movies = p.movies ?? []
        } catch let err {
            error = err.localizedDescription
        }
        loading = false
    }
}

// MARK: - Ranking

struct RankingView: View {
    @State private var movies: [Movie] = []
    @State private var period = "daily"
    @State private var loading = true
    @State private var error: String?

    private let periods = ["daily": "日榜", "weekly": "周榜", "monthly": "月榜"]

    var body: some View {
        VStack(spacing: 0) {
            Picker("周期", selection: $period) {
                ForEach(Array(periods.keys.sorted()), id: \.self) { k in
                    Text(periods[k] ?? k).tag(k)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if loading && movies.isEmpty {
                LoadingView()
            } else if let e = error, movies.isEmpty {
                ErrorStateView(message: e) { Task { await load() } }
            } else {
                MovieGridView(movies: movies, onLoadMore: nil)
            }
        }
        .task(id: period) { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let p = try await JavDBSDK.rankings(period: period)
            movies = p.movies ?? []
        } catch let err {
            error = err.localizedDescription
        }
        loading = false
    }
}

// MARK: - Top250

struct Top250View: View {
    @State private var movies: [Movie] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && movies.isEmpty {
                LoadingView()
            } else if let e = error, movies.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "star.circle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(e).font(.subheadline).foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MovieGridView(movies: movies, onLoadMore: nil)
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let p = try await JavDBSDK.top250(page: 1, limit: 50)
            movies = p.movies ?? []
        } catch let err {
            error = err.localizedDescription
        }
        loading = false
    }
}
