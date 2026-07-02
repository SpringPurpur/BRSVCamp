import Foundation
import Observation

// Preferință pur locală (UserDefaults, nesincronizată pe server) — ce grupuri arăți pe harta
// TA. Stochează setul ASCUNS, nu cel vizibil, ca un grup nou (abia creat/alăturat) să fie
// vizibil implicit, fără nicio inițializare specială la momentul aderării.
@Observable
final class MapVisibilityPreferences {
    private(set) var hiddenGroupIds: Set<UUID> = []
    private var userId: UUID?

    private var storageKey: String? {
        userId.map { "mapVisibility.hiddenGroups.\($0.uuidString)" }
    }

    func configure(userId: UUID) {
        guard self.userId != userId else { return }
        self.userId = userId
        load()
    }

    func reset() {
        userId = nil
        hiddenGroupIds = []
    }

    func isVisible(_ groupId: UUID) -> Bool {
        !hiddenGroupIds.contains(groupId)
    }

    func setVisible(_ groupId: UUID, _ visible: Bool) {
        if visible {
            hiddenGroupIds.remove(groupId)
        } else {
            hiddenGroupIds.insert(groupId)
        }
        persist()
    }

    private func load() {
        guard let key = storageKey,
              let stored = UserDefaults.standard.array(forKey: key) as? [String] else { return }
        hiddenGroupIds = Set(stored.compactMap(UUID.init))
    }

    private func persist() {
        guard let key = storageKey else { return }
        UserDefaults.standard.set(hiddenGroupIds.map(\.uuidString), forKey: key)
    }
}
