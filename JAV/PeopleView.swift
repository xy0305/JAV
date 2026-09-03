import SwiftUI

struct PeopleView: View {
    @State private var actors: [Person] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    LoadingView()
                } else if let e = error {
                    ErrorStateView(message: e) { Task { await load() } }
                } else if actors.isEmpty {
                    EmptyStateView(icon: "person.2", message: "暂无演员")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 18) {
                            ForEach(actors) { a in
                                NavigationLink(value: a) {
                                    VStack(spacing: 6) {
                                        RemoteImage(url: a.avatarURL)
                                            .frame(width: 72, height: 72).clipShape(Circle())
                                        Text(a.displayName)
                                            .font(.caption).foregroundColor(Theme.textPrimary).lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .background(Theme.bg)
            .navigationTitle("演员")
            .appDestinations()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let p = try await JavDBSDK.actors(type: 0)
            actors = p.actors ?? []
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Person detail

struct PersonDetailView: View {
    let person: Person
    @State private var movies: [Movie] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            if loading {
                LoadingView()
            } else if let e = error {
                ErrorStateView(message: e) { Task { await load() } }
            } else if movies.isEmpty {
                EmptyStateView(icon: "film", message: "暂无作品")
            } else {
                MovieGridView(movies: movies, onLoadMore: nil)
            }
        }
        .background(Theme.bg)
        .navigationTitle(person.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            RemoteImage(url: person.avatarURL)
                .frame(width: 64, height: 64).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(person.displayName).font(.headline).foregroundColor(Theme.textPrimary)
                if let z = person.nameZht, !z.isEmpty {
                    Text(z).font(.subheadline).foregroundColor(Theme.textSecondary)
                }
                if let o = person.otherName, !o.isEmpty {
                    Text("又名：\(o)").font(.caption2).foregroundColor(Theme.textSecondary).lineLimit(2)
                }
                if let vc = person.videosCount {
                    Text("\(vc) 部作品").font(.caption).foregroundColor(Theme.accent)
                }
            }
            Spacer()
        }
        .padding(16)
    }

    private func load() async {
        loading = true
        error = nil
        let id = person.externalID ?? person.id
        do {
            let p = try await JavDBSDK.personMovies("actors", id: id)
            movies = p.movies ?? []
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }
}
