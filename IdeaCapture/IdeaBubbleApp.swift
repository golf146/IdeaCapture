import SwiftUI
import Combine 

@main
struct IdeaBubbleApp: App {
    @StateObject private var vm = IdeaViewModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("主页", systemImage: "house")
                    }
                SettingsView()
                    .tabItem {
                        Label("设置", systemImage: "gear")
                    }
            }
            .environmentObject(vm) // 全局共享 ViewModel
        }
    }
}
