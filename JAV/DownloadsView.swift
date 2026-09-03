import SwiftUI

struct DownloadsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case records = "下载记录"
        case qbit = "qBittorrent"
        case aria2 = "Aria2"
        case pan115 = "115"
        case thunder = "迅雷"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .records
    @State private var data: [String: Any] = [:]
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Picker("", selection: $tab) {
                        ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)

                content
            }
            .background(Theme.bg)
            .navigationTitle("下载")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .task(id: tab) { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if loading {
            LoadingView()
        } else if let e = error {
            ErrorStateView(message: e) { Task { await load() } }
        } else {
            DynamicJSONView(title: tab.rawValue, object: data,
                            emptyMessage: "暂无任务（需配置下载器）")
        }
    }

    private func load() async {
        loading = true
        error = nil
        data = [:]
        do {
            switch tab {
            case .records: data = try await JavDBSDK.downloadRecords().raw
            case .qbit: data = try await JavDBSDK.qbittorrentTasks().raw
            case .aria2: data = try await JavDBSDK.aria2Tasks().raw
            case .pan115: data = try await JavDBSDK.pan115Tasks().raw
            case .thunder: data = try await JavDBSDK.thunderTasks().raw
            }
        } catch let err {
            error = err.localizedDescription
        }
        loading = false
    }
}
