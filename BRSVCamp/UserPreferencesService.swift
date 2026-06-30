import Foundation
import Supabase
import Observation

struct UserPrivacyPreferences: Codable {
    var shareLocation: Bool
    var shareBattery: Bool
    var appearOnline: Bool

    enum CodingKeys: String, CodingKey {
        case shareLocation = "share_location"
        case shareBattery  = "share_battery"
        case appearOnline  = "appear_online"
    }

    static let `default` = UserPrivacyPreferences(
        shareLocation: true,
        shareBattery: true,
        appearOnline: true
    )
}

@Observable
final class UserPreferencesService {
    var preferences = UserPrivacyPreferences.default
    var isLoading = false

    private let userId: UUID

    init(userId: UUID) {
        self.userId = userId
        Task { await load() }
    }

    func load() async {
        await MainActor.run { isLoading = true }
        do {
            let result: UserPrivacyPreferences = try await supabase
                .from("profiles")
                .select("share_location, share_battery, appear_online")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            await MainActor.run { preferences = result }
        } catch {
            // Rămâne pe valorile default
        }
        await MainActor.run { isLoading = false }
    }

    func setShareLocation(_ value: Bool) async throws {
        preferences.shareLocation = value
        try await persist()
    }

    func setShareBattery(_ value: Bool) async throws {
        preferences.shareBattery = value
        try await persist()
    }

    func setAppearOnline(_ value: Bool) async throws {
        preferences.appearOnline = value
        try await persist()

        // Dacă userul se ascunde, marchează imediat ca offline în user_locations
        if !value {
            try await supabase
                .from("user_locations")
                .update(["is_online": false])
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    private func persist() async throws {
        try await supabase
            .from("profiles")
            .update([
                "share_location": AnyJSON.bool(preferences.shareLocation),
                "share_battery":  AnyJSON.bool(preferences.shareBattery),
                "appear_online":  AnyJSON.bool(preferences.appearOnline),
            ])
            .eq("id", value: userId.uuidString)
            .execute()
    }
}
