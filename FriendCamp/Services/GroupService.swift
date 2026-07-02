import Foundation
import Supabase
import Observation

@Observable
final class GroupService {
    var myGroups: [MyGroupMembership] = []
    var activeGroupId: UUID?
    var isLoading = false
    var hasChecked = false
    var error: String?

    private var userId: UUID?

    var activeGroup: GroupRow? {
        myGroups.first { $0.groupId == activeGroupId }?.group
    }
    var activeUserRole: String? {
        myGroups.first { $0.groupId == activeGroupId }?.role
    }

    private func activeGroupDefaultsKey(for userId: UUID) -> String {
        "activeGroupId.\(userId.uuidString)"
    }

    func loadMyGroups(userId: UUID) async {
        self.userId = userId
        await MainActor.run { isLoading = true; error = nil }
        do {
            let rows: [GroupMembershipRow] = try await supabase
                .from("group_members")
                .select("group_id, role, groups(*)")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            await MainActor.run {
                myGroups = rows.map { MyGroupMembership(groupId: $0.groupId, role: $0.role, group: $0.group) }
                restoreOrDefaultActiveGroup(userId: userId)
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false; hasChecked = true }
    }

    private func restoreOrDefaultActiveGroup(userId: UUID) {
        let key = activeGroupDefaultsKey(for: userId)
        if let stored = UserDefaults.standard.string(forKey: key),
           let storedId = UUID(uuidString: stored),
           myGroups.contains(where: { $0.groupId == storedId }) {
            activeGroupId = storedId
        } else {
            activeGroupId = myGroups.first?.groupId
            if let activeGroupId {
                UserDefaults.standard.set(activeGroupId.uuidString, forKey: key)
            }
        }
    }

    func setActiveGroup(_ groupId: UUID) {
        guard myGroups.contains(where: { $0.groupId == groupId }) else { return }
        activeGroupId = groupId
        if let userId {
            UserDefaults.standard.set(groupId.uuidString, forKey: activeGroupDefaultsKey(for: userId))
        }
    }

    func createGroup(name: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let group: GroupRow = try await supabase
                .rpc("create_group", params: ["p_name": name])
                .execute()
                .value
            await MainActor.run {
                myGroups.append(MyGroupMembership(groupId: group.id, role: "admin", group: group))
                setActiveGroup(group.id)
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func joinGroup(code: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let groupId: UUID = try await supabase
                .rpc("join_group_by_code", params: ["p_invite_code": code])
                .execute()
                .value
            let group: GroupRow = try await supabase
                .from("groups")
                .select()
                .eq("id", value: groupId.uuidString)
                .single()
                .execute()
                .value
            await MainActor.run {
                myGroups.append(MyGroupMembership(groupId: group.id, role: "member", group: group))
                setActiveGroup(group.id)
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    // Predă rolul de admin altui membru — validat și server-side în funcția RPC
    // (nu doar prin faptul că butonul e ascuns userilor non-admin în UI).
    @discardableResult
    func transferAdmin(groupId: UUID, to userId: UUID) async -> Bool {
        await MainActor.run { isLoading = true; error = nil }
        do {
            try await supabase.rpc("transfer_admin", params: ["p_new_admin_id": userId.uuidString]).execute()
            await MainActor.run {
                if let idx = myGroups.firstIndex(where: { $0.groupId == groupId }) {
                    myGroups[idx].role = "member"
                }
                isLoading = false
            }
            return true
        } catch {
            await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            return false
        }
    }

    func reset() {
        myGroups = []
        activeGroupId = nil
        userId = nil
        hasChecked = false
        error = nil
    }
}
