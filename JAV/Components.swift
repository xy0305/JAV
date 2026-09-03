import SwiftUI

// MARK: - Movie card (grid cell)

struct MovieCardView: View {
    let movie: Movie

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                RemoteImage(url: movie.coverURL ?? movie.thumbURL)
                    .aspectRatio(0.72, contentMode: .fit)
                    .cornerRadius(10)
                    .clipped()
                if let s = movie.scoreValue {
                    Text(String(format: "%.1f", s))
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Theme.scoreColor(s))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                        .padding(5)
                }
                if let cn = movie.hasCnsub, cn {
                    Text("中字")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(5)
                }
            }
            Text(movie.displayNumber)
                .font(.caption.bold())
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Text(movie.displayTitle)
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Reusable movie grid

struct MovieGridView: View {
    let movies: [Movie]
    let onLoadMore: (() -> Void)?

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(movies) { movie in
                    NavigationLink(value: movie) {
                        MovieCardView(movie: movie)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if movie == movies.last {
                            onLoadMore?()
                        }
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Horizontal movie row

struct MovieRowView: View {
    let title: String
    let movies: [Movie]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(movies) { movie in
                        NavigationLink(value: movie) {
                            VStack(alignment: .leading, spacing: 4) {
                                RemoteImage(url: movie.thumbURL ?? movie.coverURL)
                                    .frame(width: 120, height: 166)
                                    .cornerRadius(8)
                                    .clipped()
                                Text(movie.displayNumber)
                                    .font(.caption2.bold())
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)
                                    .frame(width: 120, alignment: .leading)
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

// MARK: - Status views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中…").font(.caption).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Button("重试", action: retry)
                .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.largeTitle).foregroundColor(Theme.textSecondary)
            Text(message).font(.subheadline).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct KeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(key).foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundColor(Theme.textPrimary)
        }
        .font(.subheadline)
    }
}
