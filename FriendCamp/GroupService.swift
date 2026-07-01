import Foundation
import Supabase
import Observation

@Observable
final class GroupService {
    var currentGroup: GroupRow?
    var currentUserRole: String?
    var isLoading = false
    var hasChecked = false
    var error: String?

    func loadCurrentGroup(userId: UUID) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let rows: [GroupMembershipRow] = try await supabase
                .from("group_members")
                .select("group_id, role, groups(*)")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            await MainActor.run {
                currentGroup = rows.first?.group
                currentUserRole = rows.first?.role
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false; hasChecked = true }
    }

    func createGroup(name: String) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let group: GroupRow = try await supabase
                .rpc("create_group", params: ["p_name": name])
                .execute()
                .value
            await MainActor.run { currentGroup = group; currentUserRole = "admin" }
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
            await MainActor.run { currentGroup = group; currentUserRole = "member" }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    func reset() {
        currentGroup = nil
        currentUserRole = nil
        hasChecked = false
        error = nil
    }
}
