import SwiftUI

@main
struct JAVApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(AppConfig.shared)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task {
                    APIClient.shared.loadAuthToken()
                    appState.authToken = APIClient.shared.authToken
                }
        }
    }
}

/// Global app state (navigation + auth).
final class AppState: ObservableObject {
    @Published var authToken: String?
    @Published var isLoggedIn: Bool = false

    var isConfigured: Bool {
        !AppConfig.shared.normalizedBaseURL.isEmpty
    }

    func completeLogin(token: String?) {
        APIClient.shared.setAuthToken(token)
        authToken = token
        isLoggedIn = true
    }

    func logout() {
        Task { try? await JavDBSDK.logout() }
        APIClient.shared.setAuthToken(nil)
        authToken = nil
        isLoggedIn = false
    }
}
