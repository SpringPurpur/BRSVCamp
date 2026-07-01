import Foundation
import Supabase
import Observation

// URL-ul de redirect din emailul de confirmare — deschide aplicația direct (vezi CFBundleURLTypes din Info.plist)
// și trebuie adăugat în Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
private let authCallbackURL = URL(string: "brsvcamp://auth-callback")!

@Observable
final class AuthService {
    var session: Session?
    var isLoading = false
    var error: String?

    // Afișat în AuthView după signUp, cât timp așteptăm confirmarea prin email
    var awaitingEmailConfirmation = false
    // Declanșează un banner de succes când userul revine în app prin link-ul din email
    var justVerifiedEmail = false

    var isAuthenticated: Bool { session != nil }
    var currentUserId: UUID? { session?.user.id }

    init() {
        Task {
            // authStateChanges emite sesiunea locală (din Keychain) ca eveniment inițial,
            // apoi orice schimbare ulterioară (login, logout, refresh token)
            for await (_, session) in supabase.auth.authStateChanges {
                let validSession = session?.isExpired == true ? nil : session
                await MainActor.run {
                    self.session = validSession
                    if validSession != nil { self.awaitingEmailConfirmation = false }
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        await run {
            try await supabase.auth.signIn(email: email, password: password)
        }
    }

    func signUp(email: String, password: String, displayName: String, consentGiven: Bool) async {
        guard consentGiven else {
            await MainActor.run { self.error = "Trebuie să accepți Politica de Confidențialitate pentru a crea un cont." }
            return
        }
        await run {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: [
                    "display_name": AnyJSON.string(displayName),
                    "privacy_consent_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ],
                redirectTo: authCallbackURL
            )
            // Dacă serverul nu întoarce o sesiune, contul așteaptă confirmarea prin email
            if response.session == nil {
                await MainActor.run { self.awaitingEmailConfirmation = true }
            }
        }
    }

    // Apelat din .onOpenURL când userul revine în app prin link-ul de confirmare din email
    func handleAuthCallback(url: URL) async {
        do {
            try await supabase.auth.session(from: url)
            await MainActor.run {
                self.awaitingEmailConfirmation = false
                self.justVerifiedEmail = true
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
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
