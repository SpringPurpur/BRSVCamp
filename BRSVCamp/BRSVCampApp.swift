import SwiftUI

@main
struct BRSVCampApp: App {
    @State private var auth         = AuthService()
    @State private var groupService = GroupService()
    @State private var dataStore    = GroupDataStore()
    @State private var prefs        = UserPreferencesService()

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.isAuthenticated {
                    AuthView()
                } else if !groupService.hasChecked {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if groupService.currentGroup == nil {
                    GroupOnboardingView()
                } else {
                    ContentView()
                }
            }
            .environment(auth)
            .environment(groupService)
            .environment(dataStore)
            .environment(prefs)
            .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
            .animation(.easeInOut(duration: 0.25), value: groupService.currentGroup?.id)
            // Când userId se schimbă (login/logout), configurează serviciile
            .task(id: auth.currentUserId) {
                guard let userId = auth.currentUserId else {
                    groupService.reset()
                    dataStore.reset()
                    prefs.reset()
                    return
                }
                prefs.configure(userId: userId)
                await groupService.loadCurrentGroup(userId: userId)
            }
            // Când grupul devine disponibil (după onboarding), încarcă datele
            .task(id: groupService.currentGroup?.id) {
                guard let groupId = groupService.currentGroup?.id else { return }
                await dataStore.loadAll(groupId: groupId)
            }
        }
    }
}
