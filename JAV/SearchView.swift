import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var movies: [Movie] = []
    @State private var actors: [Person] = []
    @State private var searched = false
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                content
            }
            .background(Theme.bg)
            .navigationTitle("搜索")
            .appDestinations()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(Theme.textSecondary)
                TextField("搜索番号 / 标题", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(Theme.textPrimary)
                    .onSubmit { search() }
            }
            .padding(10)
            .background(Theme.card)
            .cornerRadius(10)

            Button("搜索") { search() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || loading)
        }
        .padding(12)
    }

    @ViewBuilder private var content: some View {
        if loading {
            LoadingView()
        } else if !searched {
            EmptyStateView(icon: "magnifyingglass", message: "输入番号或关键词开始搜索")
        } else if let e = error {
            ErrorStateView(message: e) { search() }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !actors.isEmpty {
                        Text("演员").font(.headline).padding(.horizontal, 12)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(actors) { a in
                                    NavigationLink(value: a) {
                                        VStack(spacing: 6) {
                                            RemoteImage(url: a.avatarURL)
                                                .frame(width: 60, height: 60).clipShape(Circle())
                                            Text(a.displayName).font(.caption)
                                                .foregroundColor(Theme.textPrimary).lineLimit(1)
                                        }.frame(width: 70)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    if !movies.isEmpty {
                        Text("影片").font(.headline).padding(.horizontal, 12)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 12)], spacing: 16) {
                            ForEach(movies) { m in
                                NavigationLink(value: m) {
                                    MovieCardView(movie: m)
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    } else {
                        EmptyStateView(icon: "magnifyingglass", message: "未找到结果")
                            .frame(height: 200)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        loading = true
        searched = true
        error = nil
        movies = []
        actors = []
        Task {
            do {
                let p = try await JavDBSDK.search(q: q)
                movies = p.movies ?? []
            } catch let err {
                error = err.localizedDescription
            }
            do {
                let a = try await JavDBSDK.searchActors(q: q)
                actors = a.actors ?? []
            } catch {
                // actor search failure is non-fatal
            }
            loading = false
        }
    }
}
