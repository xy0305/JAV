import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var config: AppConfig

    @State private var version: VersionInfo?
    @State private var health: HealthStatus?
    @State private var loadingInfo = false

    var body: some View {
        NavigationStack {
            Form {
                Section("服务器") {
                    HStack {
                        Text("地址")
                        Spacer()
                        Text(config.normalizedBaseURL.isEmpty ? "未设置" : config.normalizedBaseURL)
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    TextField("API Key（可选）", text: $config.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("管理") {
                    NavigationLink("服务器配置") { ConfigEditorView() }
                    NavigationLink("数据库设置") { DatabaseSetupView() }
                    NavigationLink("JAVDB 登录") { JavdbLoginView() }
                    NavigationLink("日志") { LogsView() }
                }

                Section {
                    Button("重新连接 / 更换服务器") {
                        config.baseURL = ""
                        appState.isLoggedIn = false
                        appState.authToken = nil
                    }
                    .foregroundColor(.orange)
                }

                if appState.isLoggedIn {
                    Section {
                        Button("退出登录", role: .destructive) {
                            appState.logout()
                        }
                    }
                }

                Section("服务器状态") {
                    if loadingInfo {
                        HStack { ProgressView(); Text("获取中…").font(.caption) }
                    } else {
                        if let v = version {
                            KeyValueRow(key: "版本", value: v.version ?? v.projectName ?? "—")
                        }
                        if let h = health {
                            KeyValueRow(key: "状态", value: h.status ?? "—")
                            if let m = h.mode { KeyValueRow(key: "模式", value: m) }
                        }
                        if version == nil && health == nil {
                            Text("点击刷新获取服务器信息").font(.caption).foregroundColor(Theme.textSecondary)
                        }
                    }
                    Button("刷新") { Task { await loadInfo() } }
                }

                Section("关于") {
                    KeyValueRow(key: "应用", value: "JAV")
                    KeyValueRow(key: "类型", value: "DB Online 客户端")
                    KeyValueRow(key: "平台", value: "iOS 17+")
                }
            }
            .navigationTitle("设置")
            .task { await loadInfo() }
        }
    }

    private func loadInfo() async {
        loadingInfo = true
        if let v = try? await JavDBSDK.version() { version = v }
        if let h = try? await JavDBSDK.health() { health = h }
        loadingInfo = false
    }
}
