import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isConfigured {
                ConnectionSetupView()
            } else if !appState.isLoggedIn {
                LoginView()
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
            PeopleView()
                .tabItem { Label("演员", systemImage: "person.2.fill") }
            SubscriptionsView()
                .tabItem { Label("订阅", systemImage: "square.stack.3d.up.fill") }
            DownloadsView()
                .tabItem { Label("下载", systemImage: "arrow.down.circle.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}
