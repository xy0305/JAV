import SwiftUI

/// First-run screen: enter the DB Online server address.
struct ConnectionSetupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var config: AppConfig
    @State private var urlText: String = ""
    @State private var testing = false
    @State private var errorMessage: String?
    @State private var testOK = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.accent)
                    Text("JAV")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("连接你的 DB Online 服务器")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("服务器地址")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                    TextField("http://192.168.1.10:39090", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Theme.card)
                        .cornerRadius(12)
                        .foregroundColor(Theme.textPrimary)
                    if let e = errorMessage {
                        Text(e).font(.caption).foregroundColor(.red)
                    }
                    if testOK {
                        Label("连接成功", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundColor(.green)
                    }
                }
                Button {
                    connect()
                } label: {
                    if testing {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 8)
                    } else {
                        Text("连接").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                }
                .buttonStyle(.plain)
                .background(Theme.accent)
                .foregroundColor(.white)
                .cornerRadius(14)
                .disabled(testing || urlText.trimmingCharacters(in: .whitespaces).isEmpty)

                Text("默认端口 39090。填入 NAS/服务器地址，例如 http://192.168.1.10:39090")
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
                Spacer()
            }
            .padding(28)
        }
    }

    private func connect() {
        var s = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.contains("://") { s = "http://" + s }
        while s.hasSuffix("/") { s.removeLast() }
        config.baseURL = s
        testing = true
        errorMessage = nil
        testOK = false
        Task {
            do {
                _ = try await JavDBSDK.version()
                testOK = true
                try? await Task.sleep(nanoseconds: 400_000_000)
                appState.isLoggedIn = true   // auth may be disabled; proceed to main
            } catch {
                errorMessage = error.localizedDescription
            }
            testing = false
        }
    }
}

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var config: AppConfig
    @State private var password = ""
    @State private var loggingIn = false
    @State private var errorMessage: String?
    @State private var covers: [String] = []

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    if let c = covers.first {
                        RemoteImage(url: c)
                            .frame(height: 260)
                            .cornerRadius(18)
                            .padding(.top, 12)
                    } else {
                        VStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 52))
                                .foregroundColor(Theme.accent)
                        }
                        .frame(height: 220)
                    }
                    Text("DB Online")
                        .font(.title2.bold())
                    VStack(spacing: 10) {
                        SecureField("访问密码", text: $password)
                            .padding(14)
                            .background(Theme.card)
                            .cornerRadius(12)
                            .foregroundColor(Theme.textPrimary)
                        if let e = errorMessage {
                            Text(e).font(.caption).foregroundColor(.red)
                        }
                        Button {
                            login()
                        } label: {
                            if loggingIn {
                                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 6)
                            } else {
                                Text("登录").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                            }
                        }
                        .buttonStyle(.plain)
                        .background(Theme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .disabled(loggingIn)

                        Button("未启用密码？直接浏览") {
                            appState.isLoggedIn = true
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                    }
                    Button {
                        config.baseURL = ""
                        appState.isLoggedIn = false
                    } label: {
                        Label("更换服务器", systemImage: "server.rack")
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(24)
            }
        }
        .task { await loadCovers() }
    }

    private func login() {
        loggingIn = true
        errorMessage = nil
        Task {
            do {
                let token = try await JavDBSDK.login(password: password)
                appState.completeLogin(token: token)
            } catch {
                errorMessage = error.localizedDescription
            }
            loggingIn = false
        }
    }

    private func loadCovers() async {
        if let p = try? await JavDBSDK.loginCovers(limit: 12) {
            covers = (p.covers ?? p.images ?? []).compactMap { $0 }
        }
    }
}
