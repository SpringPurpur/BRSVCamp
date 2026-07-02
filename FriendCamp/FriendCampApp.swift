import SwiftUI

@main
struct FriendCampApp: App {
    @State private var auth         = AuthService()
    @State private var groupService = GroupService()
    @State private var dataStore    = GroupDataStore()
    @State private var prefs        = UserPreferencesService()

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.hasCheckedSession {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !auth.isAuthenticated {
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
            // Link-ul din emailul de confirmare deschide aplicația direct (friendcamp://auth-callback)
            .onOpenURL { url in
                Task { await auth.handleAuthCallback(url: url) }
            }
            .overlay(alignment: .top) {
                if auth.justVerifiedEmail {
                    EmailConfirmedBanner()
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation { auth.justVerifiedEmail = false }
                        }
                }
            }
            .animation(.spring(duration: 0.4), value: auth.justVerifiedEmail)
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

// MARK: - EmailConfirmedBanner

private struct EmailConfirmedBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Email confirmat cu succes!")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6)
        .padding(.horizontal)
    }
}
