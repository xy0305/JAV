import SwiftUI

struct SubscriptionsView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case following = "关注"
        case subs = "订阅"
        case videos = "订阅视频"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .following
    @State private var data: [String: Any] = [:]
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
                }
                .pickerStyle(.segmented)
                .padding(12)

                content
            }
            .background(Theme.bg)
            .navigationTitle("订阅")
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
                            emptyMessage: "暂无数据（需服务器配置数据库）")
        }
    }

    private func load() async {
        loading = true
        error = nil
        data = [:]
        do {
            switch tab {
            case .following:
                data = try await JavDBSDK.followingUsers().raw
            case .subs:
                data = try await JavDBSDK.subscriptions().raw
            case .videos:
                data = try await JavDBSDK.subscriptionVideos().raw
            }
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }
}
