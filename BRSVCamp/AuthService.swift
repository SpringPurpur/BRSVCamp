import Foundation
import Supabase
import Observation

@Observable
final class AuthService {
    var session: Session?
    var isLoading = false
    var error: String?

    var isAuthenticated: Bool { session != nil }
    var currentUserId: UUID? { session?.user.id }

    init() {
        Task {
            // Restaurează sesiunea din Keychain dacă există
            session = try? await supabase.auth.session
            // Ascultă schimbări de stare (login, logout, refresh token)
            for await (_, session) in supabase.auth.authStateChanges {
                await MainActor.run { self.session = session }
            }
        }
    }

    func signIn(email: String, password: String) async {
        await run {
            try await supabase.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        await run {
            try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": AnyJSON.string(displayName)]
            )
        }
    }

    func signOut() async {
        await run {
            try await supabase.auth.signOut()
        }
    }

    // Șterge toate datele personale și contul — ireversibil
    func deleteAccount() async {
        await run {
            try await supabase.rpc("delete_user_account").execute()
            try await supabase.auth.signOut()
        }
    }

    // MARK: - Helper

    private func run(_ block: () async throws -> Void) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        do {
            try await block()
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }
}
