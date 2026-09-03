import SwiftUI

// MARK: - Logs

struct LogsView: View {
    @State private var entries: [String] = []
    @State private var totalCount = 0
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading && entries.isEmpty {
                LoadingView()
            } else if let e = error, entries.isEmpty {
                ErrorStateView(message: e) { Task { await load() } }
            } else if entries.isEmpty {
                EmptyStateView(icon: "doc.text", message: "暂无日志")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(Theme.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("日志（\(totalCount)）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let d = try await JavDBSDK.logs().raw
            totalCount = d["total_count"] as? Int ?? 0
            if let arr = d["entries"] as? [Any] {
                entries = arr.map { stringify($0) }
            } else {
                entries = []
            }
        } catch {
            error = error.localizedDescription
        }
        loading = false
    }

    private func stringify(_ v: Any) -> String {
        if let s = v as? String { return s }
        if let d = v as? [String: Any] {
            let ts = d["timestamp"] as? String ?? d["time"] as? String ?? ""
            let lv = d["level"] as? String ?? ""
            let msg = d["message"] as? String ?? d["msg"] as? String ?? ""
            return [ts, lv, msg].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return String(describing: v)
    }
}

// MARK: - Database setup

struct DatabaseSetupView: View {
    @State private var host = ""
    @State private var port = "5432"
    @State private var user = "postgres"
    @State private var password = ""
    @State private var dbname = "db_online"
    @State private var sslmode = "disable"
    @State private var statusInfo = ""
    @State private var loading = true
    @State private var busy = false
    @State private var alertMsg = ""
    @State private var showAlert = false

    private enum Action { case test, initialize, restart }

    var body: some View {
        Form {
            Section("当前状态") {
                Text(statusInfo.isEmpty ? "加载中…" : statusInfo)
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
            }
            Section("数据库连接（PostgreSQL）") {
                TextField("主机", text: $host).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("端口", text: $port).keyboardType(.numberPad)
                TextField("用户", text: $user).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("密码", text: $password)
                TextField("数据库名", text: $dbname).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("SSL 模式", text: $sslmode).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            Section("操作") {
                Button("测试连接") { Task { await run(.test) } }.disabled(busy)
                Button("初始化数据库") { Task { await run(.initialize) } }.disabled(busy)
                Button("重启服务", role: .destructive) { Task { await run(.restart) } }.disabled(busy)
            }
        }
        .navigationTitle("数据库设置")
        .task { await load() }
        .alert(alertMsg, isPresented: $showAlert) { Button("好", role: .cancel) {} }
    }

    private func dbBody() -> [String: Any] {
        ["host": host, "port": Int(port) ?? 5432, "user": user,
         "password": password, "dbname": dbname, "sslmode": sslmode]
    }

    private func load() async {
        loading = true
        do {
            let d = try await JavDBSDK.setupStatus().raw
            let cur = d["current"] as? [String: Any] ?? [:]
            host = cur["host"] as? String ?? "postgres"
            port = "\(cur["port"] as? Int ?? 5432)"
            user = cur["user"] as? String ?? "postgres"
            dbname = cur["dbname"] as? String ?? "db_online"
            sslmode = cur["sslmode"] as? String ?? "disable"
            let configured = d["db_configured"] as? Bool ?? false
            let available = d["available"] as? Bool ?? false
            statusInfo = "数据库\(configured ? "已配置" : "未配置") · 服务\(available ? "可用" : "不可用")"
        } catch {
            statusInfo = "无法获取状态：\(error.localizedDescription)"
        }
        loading = false
    }

    private func run(_ action: Action) async {
        busy = true
        do {
            let result: JSONObject
            switch action {
            case .test:
                result = try await JavDBSDK.setupTestConnection(dbBody())
                alertMsg = "连接成功"
            case .initialize:
                result = try await JavDBSDK.setupInitialize(dbBody())
                alertMsg = "初始化完成"
            case .restart:
                result = try await JavDBSDK.setupRestart()
                alertMsg = "已触发重启"
            }
            if let m = result.raw["message"] as? String, !m.isEmpty {
                alertMsg = m
            }
        } catch {
            alertMsg = error.localizedDescription
        }
        busy = false
        showAlert = true
    }
}

// MARK: - JAVDB account login

struct JavdbLoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var busy = false
    @State private var userInfo = ""
    @State private var alertMsg = ""
    @State private var showAlert = false

    var body: some View {
        Form {
            Section {
                Text("登录 JAVDB 账号，服务器会保存 Authorization 用于 Top250 与在线播放。")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                TextField("用户名 / 邮箱", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("密码", text: $password)
                Button("登录并获取 Token") { Task { await login() } }
                    .disabled(busy || username.isEmpty || password.isEmpty)
            }
            if !userInfo.isEmpty {
                Section("当前账号") {
                    Text(userInfo).font(.subheadline).foregroundColor(Theme.textSecondary)
                }
            }
        }
        .navigationTitle("JAVDB 登录")
        .task { await loadUser() }
        .alert(alertMsg, isPresented: $showAlert) { Button("好", role: .cancel) {} }
    }

    private func login() async {
        busy = true
        do {
            let d = try await JavDBSDK.javdbLogin(username: username, password: password).raw
            alertMsg = "登录成功"
            if let m = d["message"] as? String, !m.isEmpty { alertMsg = m }
            await loadUser()
        } catch {
            alertMsg = error.localizedDescription
        }
        busy = false
        showAlert = true
    }

    private func loadUser() async {
        guard let d = try? await JavDBSDK.javdbUserInfo().raw else { return }
        var parts: [String] = []
        for key in ["username", "name", "nickname", "email"] {
            if let s = d[key] as? String, !s.isEmpty { parts.append(s) }
        }
        if let nested = d["user"] as? [String: Any] {
            for key in ["username", "name", "nickname", "email"] {
                if let s = nested[key] as? String, !s.isEmpty { parts.append(s) }
            }
        }
        if parts.isEmpty {
            if let vip = d["is_vip"] as? Bool { parts.append(vip ? "VIP" : "非 VIP") }
        }
        userInfo = parts.joined(separator: " · ")
    }
}
