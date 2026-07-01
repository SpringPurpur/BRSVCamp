import Foundation
import MapKit
import SwiftUI
import Supabase
import Observation

@Observable
final class GroupDataStore {
    var members:  [GroupMember]      = []
    var pois:     [PointOfInterest]  = []
    var posts:    [BlogPost]         = []
    var expenses: [Expense]          = []
    var isLoading = false

    // MARK: - Load all

    func loadAll(groupId: UUID) async {
        await MainActor.run { isLoading = true }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMembers(groupId: groupId) }
            group.addTask { await self.loadPOIs(groupId: groupId) }
            group.addTask { await self.loadPosts(groupId: groupId) }
            group.addTask { await self.loadExpenses(groupId: groupId) }
        }
        await MainActor.run { isLoading = false }
    }

    // MARK: - Members (group_member_status view)

    func loadMembers(groupId: UUID) async {
        do {
            let rows: [MemberStatusRow] = try await supabase
                .from("group_member_status")
                .select()
                .eq("group_id", value: groupId.uuidString)
                .execute()
                .value
            let mapped = rows.map { GroupMember(from: $0) }
            await MainActor.run { members = mapped }
        } catch { }
    }

    func pollMembers(groupId: UUID) async {
        while !Task.isCancelled {
            await loadMembers(groupId: groupId)
            try? await Task.sleep(nanoseconds: 15_000_000_000)
        }
    }

    // Actualizează membrii aproape instant la orice schimbare în user_locations,
    // în loc să aștepte până la 15s pentru următorul poll (necesită ca tabela
    // user_locations să fie adăugată la publicația supabase_realtime — vezi schema).
    func subscribeToLocationUpdates(groupId: UUID) async {
        let channel = supabase.channel("group-locations-\(groupId.uuidString)")
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "user_locations",
            filter: .eq("group_id", value: groupId.uuidString)
        )
        try? await channel.subscribeWithError()
        for await _ in changes {
            await loadMembers(groupId: groupId)
        }
        await supabase.removeChannel(channel)
    }

    // MARK: - POIs

    func loadPOIs(groupId: UUID) async {
        do {
            let rows: [POIRow] = try await supabase
                .from("points_of_interest")
                .select("*, profiles(display_name)")
                .eq("group_id", value: groupId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            let mapped = rows.map { PointOfInterest(from: $0) }
            await MainActor.run { pois = mapped }
        } catch { }
    }

    // MARK: - Blog posts

    func loadPosts(groupId: UUID) async {
        do {
            let rows: [BlogPostRecord] = try await supabase
                .from("blog_posts")
                .select("*, profiles(display_name, avatar_color), points_of_interest(id, title, category, latitude, longitude, pin_color), blog_post_photos(id, storage_path, order_index)")
                .eq("group_id", value: groupId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            let mapped = rows.enumerated().map { idx, row in BlogPost(from: row, colorIndex: idx) }
            await MainActor.run { posts = mapped }
        } catch { }
    }

    // MARK: - Expenses

    func loadExpenses(groupId: UUID) async {
        do {
            let rows: [ExpenseRecord] = try await supabase
                .from("expenses")
                .select("id, group_id, paid_by, amount, currency, category, description, date, paid_by_profile:profiles!paid_by(display_name, avatar_color), expense_splits(id, user_id, amount, settled, member:profiles(display_name, avatar_color))")
                .eq("group_id", value: groupId.uuidString)
                .order("date", ascending: false)
                .execute()
                .value
            let mapped = rows.map { Expense(from: $0) }
            await MainActor.run { expenses = mapped }
        } catch { }
    }

    // MARK: - Upload location

    func uploadLocation(userId: UUID, groupId: UUID,
                        coordinate: CLLocationCoordinate2D, batteryPercent: Int?) async {
        // is_online nu se mai trimite — group_member_status îl calculează din recența updated_at
        var payload: [String: AnyJSON] = [
            "user_id":   .string(userId.uuidString),
            "group_id":  .string(groupId.uuidString),
            "latitude":  .double(coordinate.latitude),
            "longitude": .double(coordinate.longitude),
            "updated_at": .string(ISO8601DateFormatter().string(from: Date())),
        ]
        if let pct = batteryPercent {
            payload["battery_level"] = .double(Double(pct))
        }
        _ = try? await supabase.from("user_locations").upsert(payload).execute()
    }

    func reset() {
        members  = []
        pois     = []
        posts    = []
        expenses = []
    }
}

// MARK: - DTO → UI model mapping

private extension GroupMember {
    init(from row: MemberStatusRow) {
        self.init(
            id: row.userId,
            name: row.displayName,
            avatarColor: Color(hex: row.avatarColor),
            coordinate: CLLocationCoordinate2D(
                latitude:  row.latitude  ?? 0,
                longitude: row.longitude ?? 0
            ),
            isOnline: row.isOnline ?? false,
            lastSeen: row.updatedAt ?? Date(),
            battery:  row.batteryLevel ?? 0
        )
    }
}

private extension PointOfInterest {
    init(from row: POIRow) {
        self.init(
            id: row.id,
            title: row.title,
            description: row.description ?? "",
            coordinate: CLLocationCoordinate2D(latitude: row.latitude, longitude: row.longitude),
            category: row.category,
            createdBy: row.author?.displayName ?? "Necunoscut",
            createdById: row.createdBy,
            date: row.createdAt,
            photoURL: row.photoURL.flatMap(URL.init(string:)),
            pinColor: row.pinColor.map { Color(hex: $0) }
        )
    }

    // Referință minimală, folosită doar pentru badge-ul POI din postările de blog
    // (embed-ul points_of_interest din blog_posts nu include description/createdBy/date).
    init(from ref: POIRefRow) {
        self.init(
            id: ref.id,
            title: ref.title,
            description: "",
            coordinate: CLLocationCoordinate2D(latitude: ref.latitude, longitude: ref.longitude),
            category: ref.category,
            createdBy: "",
            date: Date(),
            pinColor: ref.pinColor.map { Color(hex: $0) }
        )
    }
}

private let gradientPalettes: [[Color]] = [
    [.blue, .cyan], [.orange, .red], [.green, .teal],
    [.purple, .indigo], [.pink, .orange], [.teal, .blue]
]

private extension BlogPost {
    init(from row: BlogPostRecord, colorIndex: Int) {
        let authorColor = Color(hex: row.author?.avatarColor ?? "#3B82F6")
        let dummyAuthor = GroupMember(
            id: UUID(),
            name: row.author?.displayName ?? "Necunoscut",
            avatarColor: authorColor,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            isOnline: false,
            lastSeen: Date(),
            battery: 0
        )
        let photoURLs = row.photos
            .sorted { $0.orderIndex < $1.orderIndex }
            .compactMap { try? supabase.storage.from("blog-photos").getPublicURL(path: $0.storagePath) }
        self.init(
            id: row.id,
            author: dummyAuthor,
            title: row.title,
            content: row.content,
            date: row.createdAt,
            poi: row.poi.map { PointOfInterest(from: $0) },
            headerColors: gradientPalettes[colorIndex % gradientPalettes.count],
            photos: photoURLs
        )
    }
}

private extension Expense {
    init(from row: ExpenseRecord) {
        let payerColor = Color(hex: row.paidByProfile?.avatarColor ?? "#3B82F6")
        let payer = GroupMember(
            id: row.paidById,
            name: row.paidByProfile?.displayName ?? "Necunoscut",
            avatarColor: payerColor,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            isOnline: false, lastSeen: Date(), battery: 0
        )
        let splits = row.splits.map { ExpenseSplit(from: $0) }
        self.init(
            id: row.id,
            paidBy: payer,
            amount: row.amount,
            currency: row.currency,
            category: ExpenseCategory(dbValue: row.category),
            description: row.description,
            date: row.date,
            splits: splits
        )
    }
}

private extension ExpenseSplit {
    init(from row: ExpenseSplitRow) {
        let memberColor = Color(hex: row.member?.avatarColor ?? "#3B82F6")
        let member = GroupMember(
            id: row.userId,
            name: row.member?.displayName ?? "Necunoscut",
            avatarColor: memberColor,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            isOnline: false, lastSeen: Date(), battery: 0
        )
        self.init(id: row.id, member: member, amount: row.amount, settled: row.settled)
    }
}

private extension ExpenseCategory {
    init(dbValue: String) {
        switch dbValue {
        case "food":          self = .food
        case "transport":     self = .transport
        case "accommodation": self = .accommodation
        case "activities":    self = .activities
        default:              self = .other
        }
    }
}
