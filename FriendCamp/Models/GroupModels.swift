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
    let role: String
    let group: GroupRow

    enum CodingKeys: String, CodingKey {
        case groupId = "group_id"
        case role
        case group   = "groups"
    }
}

// MARK: - group_member_status view

struct MemberStatusRow: Codable {
    let groupId: UUID
    let userId: UUID
    let displayName: String
    let avatarColor: String
    let role: String
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
        case role
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
    let pinColor: String?
    let createdAt: Date
    let createdBy: UUID
    let author: AuthorRef?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId     = "group_id"
        case title, description, latitude, longitude, category
        case photoURL    = "photo_url"
        case pinColor    = "pin_color"
        case createdAt   = "created_at"
        case createdBy   = "created_by"
        case author      = "profiles"
    }
}

// MARK: - Blog posts

struct BlogPostRecord: Codable {
    let id: UUID
    let groupId: UUID
    let authorId: UUID
    let title: String
    let content: String
    let createdAt: Date
    let author: AuthorRef?
    let poi: POIRefRow?
    let photos: [BlogPostPhotoRow]

    enum CodingKeys: String, CodingKey {
        case id
        case groupId   = "group_id"
        case authorId  = "author_id"
        case title, content
        case createdAt = "created_at"
        case author    = "profiles"
        case poi       = "points_of_interest"
        case photos    = "blog_post_photos"
    }
}

struct POIRefRow: Codable {
    let id: UUID
    let title: String
    let category: String
    let latitude: Double
    let longitude: Double
    let pinColor: String?

    enum CodingKeys: String, CodingKey {
        case id, title, category, latitude, longitude
        case pinColor = "pin_color"
    }
}

struct BlogPostPhotoRow: Codable {
    let id: UUID
    let storagePath: String
    let orderIndex: Int

    enum CodingKeys: String, CodingKey {
        case id
        case storagePath = "storage_path"
        case orderIndex  = "order_index"
    }
}

// MARK: - Expenses

struct ExpenseRecord: Codable {
    let id: UUID
    let groupId: UUID
    let paidById: UUID
    let amount: Double
    let currency: String
    let category: String
    let description: String
    // Coloana Postgres e "date" (fără oră) — vine ca "yyyy-MM-dd", nu ca ISO8601 complet,
    // deci decoder-ul implicit (care acceptă doar timestamp-uri ISO8601) ar eșua pe Date direct.
    let date: String
    let receiptURL: String?
    let editCount: Int
    let updatedAt: Date?
    let paidByProfile: AuthorRef?
    let splits: [ExpenseSplitRow]

    enum CodingKeys: String, CodingKey {
        case id
        case groupId      = "group_id"
        case paidById     = "paid_by"
        case amount, currency, category, description, date
        case receiptURL   = "receipt_url"
        case editCount    = "edit_count"
        case updatedAt    = "updated_at"
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
