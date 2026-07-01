import Foundation
import MapKit
import SwiftUI

// MARK: - GroupMember

struct GroupMember: Identifiable {
    let id: UUID
    let name: String
    let avatarColor: Color
    let coordinate: CLLocationCoordinate2D
    let isOnline: Bool
    let lastSeen: Date
    let battery: Int

    var initials: String { String(name.prefix(1)) }

    init(id: UUID = UUID(), name: String, avatarColor: Color, coordinate: CLLocationCoordinate2D,
         isOnline: Bool, lastSeen: Date, battery: Int) {
        self.id = id; self.name = name; self.avatarColor = avatarColor
        self.coordinate = coordinate; self.isOnline = isOnline
        self.lastSeen = lastSeen; self.battery = battery
    }
}

// MARK: - Point of Interest

struct PointOfInterest: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    let createdBy: String
    let createdById: UUID
    let date: Date
    let photoURL: URL?
    let pinColor: Color?

    // Iconiță unică pentru toate POI-urile — categoria e text liber, nu mai poate fi
    // mapată automat la o iconiță specifică. Culoarea rămâne personalizabilă (pinColor).
    static let pinIcon = "mappin.circle.fill"
    static let defaultPinColor = Color.gray

    // Folosită peste tot în UI în loc de pinColor direct, ca fallback-ul să fie într-un singur loc.
    var displayColor: Color { pinColor ?? PointOfInterest.defaultPinColor }

    init(id: UUID = UUID(), title: String, description: String, coordinate: CLLocationCoordinate2D,
         category: String, createdBy: String, createdById: UUID = UUID(), date: Date,
         photoURL: URL? = nil, pinColor: Color? = nil) {
        self.id = id; self.title = title; self.description = description
        self.coordinate = coordinate; self.category = category
        self.createdBy = createdBy; self.createdById = createdById
        self.date = date; self.photoURL = photoURL; self.pinColor = pinColor
    }
}

// MARK: - Blog

struct BlogPhoto: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let storagePath: String
}

struct BlogPost: Identifiable {
    let id: UUID
    let author: GroupMember
    let title: String
    let content: String
    let date: Date
    let poi: PointOfInterest?
    let headerColors: [Color]
    let photos: [BlogPhoto]

    // Maxim de poze pe o postare — impus doar client-side (UX), nu e o constrângere în DB.
    static let maxPhotos = 5

    init(id: UUID = UUID(), author: GroupMember, title: String, content: String,
         date: Date, poi: PointOfInterest?, headerColors: [Color], photos: [BlogPhoto] = []) {
        self.id = id; self.author = author; self.title = title; self.content = content
        self.date = date; self.poi = poi; self.headerColors = headerColors; self.photos = photos
    }
}

// MARK: - Expenses

struct Expense: Identifiable {
    let id: UUID
    let paidBy: GroupMember
    let amount: Double
    let currency: String
    let category: ExpenseCategory
    let description: String
    let date: Date
    var splits: [ExpenseSplit]

    init(id: UUID = UUID(), paidBy: GroupMember, amount: Double, currency: String,
         category: ExpenseCategory, description: String, date: Date, splits: [ExpenseSplit]) {
        self.id = id; self.paidBy = paidBy; self.amount = amount; self.currency = currency
        self.category = category; self.description = description; self.date = date; self.splits = splits
    }
}

struct ExpenseSplit: Identifiable {
    let id: UUID
    let member: GroupMember
    let amount: Double
    var settled: Bool

    init(id: UUID = UUID(), member: GroupMember, amount: Double, settled: Bool) {
        self.id = id; self.member = member; self.amount = amount; self.settled = settled
    }
}

enum ExpenseCategory: String, CaseIterable {
    case food = "Mâncare"
    case transport = "Transport"
    case accommodation = "Cazare"
    case activities = "Activități"
    case other = "Diverse"

    var systemImage: String {
        switch self {
        case .food:          return "fork.knife"
        case .transport:     return "car.fill"
        case .accommodation: return "house.fill"
        case .activities:    return "figure.hiking"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .food:          return .orange
        case .transport:     return .blue
        case .accommodation: return .purple
        case .activities:    return .green
        case .other:         return .gray
        }
    }
}

// MARK: - Mock Data

enum MockData {
    static let currentUser = members[0]

    static let members: [GroupMember] = [
        GroupMember(
            name: "Vlad", avatarColor: .blue,
            coordinate: CLLocationCoordinate2D(latitude: 45.9432, longitude: 24.9668),
            isOnline: true, lastSeen: Date(), battery: 82
        ),
        GroupMember(
            name: "Ana", avatarColor: .pink,
            coordinate: CLLocationCoordinate2D(latitude: 45.9450, longitude: 24.9700),
            isOnline: true, lastSeen: Date(), battery: 65
        ),
        GroupMember(
            name: "Mihai", avatarColor: .green,
            coordinate: CLLocationCoordinate2D(latitude: 45.9415, longitude: 24.9650),
            isOnline: false,
            lastSeen: Calendar.current.date(byAdding: .minute, value: -23, to: Date())!,
            battery: 40
        ),
        GroupMember(
            name: "Ioana", avatarColor: .orange,
            coordinate: CLLocationCoordinate2D(latitude: 45.9460, longitude: 24.9720),
            isOnline: true, lastSeen: Date(), battery: 91
        ),
    ]

    static let pois: [PointOfInterest] = [
        PointOfInterest(
            title: "Cascada Vălul Miresei",
            description: "Cascadă superbă, 15 min de mers pe jos de la parcare. Merită tot drumul!",
            coordinate: CLLocationCoordinate2D(latitude: 45.9440, longitude: 24.9660),
            category: "Belvedere", createdBy: "Vlad",
            date: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        ),
        PointOfInterest(
            title: "Restaurant Vânătorul",
            description: "Mâncare tradițională excelentă, prețuri ok. Ciorbă de vănat recomandată.",
            coordinate: CLLocationCoordinate2D(latitude: 45.9425, longitude: 24.9690),
            category: "Restaurant", createdBy: "Ana",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        ),
        PointOfInterest(
            title: "Tabăra de noapte",
            description: "Loc bun pentru cort, aproape de izvor. Apă rece și curată.",
            coordinate: CLLocationCoordinate2D(latitude: 45.9455, longitude: 24.9640),
            category: "Tabără", createdBy: "Mihai",
            date: Calendar.current.date(byAdding: .hour, value: -5, to: Date())!
        ),
    ]

    static let posts: [BlogPost] = [
        BlogPost(
            author: members[0],
            title: "Ziua 1: Am ajuns!",
            content: "Am pornit dis de dimineață și am ajuns la prânz. Drumul a fost lung dar peisajele au meritat. Prima oprire a fost la cascadă — absolut spectaculos. Apa era înghețată dar Mihai tot a băut din ea.",
            date: Calendar.current.date(byAdding: .hour, value: -3, to: Date())!,
            poi: pois[0],
            headerColors: [.blue, .cyan]
        ),
        BlogPost(
            author: members[1],
            title: "Seara la restaurant",
            content: "Am găsit un restaurant minunat la marginea pădurii. Ciorbă de vănat și mămăligă cu brânză — exact ce ne trebuia după atâta mers. Vlad a mâncat de două ori.",
            date: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!,
            poi: pois[1],
            headerColors: [.orange, .red]
        ),
        BlogPost(
            author: members[2],
            title: "Corturile montate",
            content: "Am găsit un loc perfect lângă un izvor. Noaptea a fost rece dar focul a ținut de cald. Mihai a venit la 2 noaptea fără să anunțe pe nimeni.",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            poi: pois[2],
            headerColors: [.green, .teal]
        ),
    ]

    static let expenses: [Expense] = [
        Expense(
            paidBy: members[0], amount: 120.0, currency: "RON",
            category: .food, description: "Restaurant Vânătorul — cina",
            date: Calendar.current.date(byAdding: .hour, value: -8, to: Date())!,
            splits: [
                ExpenseSplit(member: members[0], amount: 30.0, settled: true),
                ExpenseSplit(member: members[1], amount: 30.0, settled: false),
                ExpenseSplit(member: members[2], amount: 30.0, settled: false),
                ExpenseSplit(member: members[3], amount: 30.0, settled: false),
            ]
        ),
        Expense(
            paidBy: members[1], amount: 85.0, currency: "RON",
            category: .transport, description: "Benzină + taxe drum",
            date: Calendar.current.date(byAdding: .hour, value: -12, to: Date())!,
            splits: [
                ExpenseSplit(member: members[0], amount: 21.25, settled: false),
                ExpenseSplit(member: members[1], amount: 21.25, settled: true),
                ExpenseSplit(member: members[2], amount: 21.25, settled: false),
                ExpenseSplit(member: members[3], amount: 21.25, settled: false),
            ]
        ),
        Expense(
            paidBy: members[3], amount: 200.0, currency: "RON",
            category: .accommodation, description: "Cabana — 2 nopți",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            splits: [
                ExpenseSplit(member: members[0], amount: 50.0, settled: false),
                ExpenseSplit(member: members[1], amount: 50.0, settled: false),
                ExpenseSplit(member: members[2], amount: 50.0, settled: false),
                ExpenseSplit(member: members[3], amount: 50.0, settled: true),
            ]
        ),
    ]
}