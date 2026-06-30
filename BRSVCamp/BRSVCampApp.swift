import SwiftUI

@main
struct BRSVCampApp: App {
    @State private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isAuthenticated {
                    ContentView()
                } else {
                    AuthView()
                }
            }
            .environment(auth)
            .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
        }
    }
}
