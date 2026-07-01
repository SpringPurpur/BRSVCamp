import Foundation

// MARK: - Group

struct GroupRow: Codable, Identifiable {
    let id: UUID
    let name: String
    let inviteCode: String
    let createdBy: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case createdBy  = "created_by"
        case createdAt  = "created_at"
    }
}

// MARK: - Group membership (embed select pentru loadCurrentGroup)

struct GroupMembershipRow: Codable {
    let groupId: UUID
    let group: GroupRow

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case group   = "groups"
    }
}

// MARK: - group_member_status view

struct MemberStatusRow: Codable {
    let groupId: UUID
    let userId: UUID
    let displayName: String
    let avatarColor: String
    let latitude: Double?
    let longitude: Double?
    let batteryLevel: Int?
    let isOnline: Bool?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case groupId      = "group_id"
        case userId       = "user_id"
        case displayName  = "display_name"
        case avatarColor  = "avatar_color"
        case latitude, longitude
        case batteryLevel = "battery_level"
        case isOnline     = "is_online"
        case updatedAt    = "updated_at"
    }
}

// MARK: - Points of Interest

struct POIRow: Codable {
    let id: UUID
    let groupId: UUID
    let title: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let category: String
    let photoURL: String?
    let createdAt: Date
    let author: AuthorRef?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId     = "group_id"
        case title, description, latitude, longitude, category
        case photoURL    = "photo_url"
        case createdAt   = "created_at"
        case author      = "profiles"
    }
}

// MARK: - Blog posts

struct BlogPostRow: Codable {
    let id: UUID
    let groupId: UUID
    let title: String
    let content: String
    let createdAt: Date
    let author: AuthorRef?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId   = "group_id"
        case title, content
        case createdAt = "created_at"
        case author    = "profiles"
    }
}

// MARK: - Expenses

struct ExpenseRow: Codable {
    let id: UUID
    let groupId: UUID
    let paidById: UUID
    let amount: Double
    let currency: String
    let category: String
    let description: String
    let date: Date
    let paidByProfile: AuthorRef?
    let splits: [ExpenseSplitRow]

    enum CodingKeys: String, CodingKey {
        case id
        case groupId      = "group_id"
        case paidById     = "paid_by"
        case amount, currency, category, description, date
        case paidByProfile = "paid_by_profile"
        case splits        = "expense_splits"
    }
}

struct ExpenseSplitRow: Codable {
    let id: UUID
    let userId: UUID
    let amount: Double
    let settled: Bool
    let member: AuthorRef?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case amount, settled
        case member
    }
}

// MARK: - Shared

struct AuthorRef: Codable {
    let displayName: String
    let avatarColor: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarColor = "avatar_color"
    }
}
