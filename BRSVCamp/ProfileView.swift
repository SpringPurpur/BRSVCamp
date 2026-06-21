import SwiftUI

struct ProfileView: View {
    let currentUser = MockData.currentUser
    let members = MockData.members
    private let groupName = "Aventurierii"
    private let inviteCode = "BRSV-4829"

    var body: some View {
        NavigationStack {
            List {
                // User header (outside list styling)
                Section {
                    UserHeaderCard(user: currentUser)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Group section
                Section {
                    GroupInfoRow(name: groupName, inviteCode: inviteCode)
                } header: {
                    Text("Grupul meu")
                }

                // Members section
                Section {
                    ForEach(members) { member in
                        MemberListRow(member: member, isCurrentUser: member.id == currentUser.id)
                    }
                } header: {
                    Text("Membrii (\(members.count))")
                }

                // Trip stats section
                Section {
                    StatRow(icon: "mappin.circle.fill", color: .orange,
                            label: "Puncte marcate", value: "\(MockData.pois.count)")
                    StatRow(icon: "doc.text.fill", color: .blue,
                            label: "Postări blog", value: "\(MockData.posts.count)")
                    StatRow(icon: "creditcard.fill", color: .purple,
                            label: "Cheltuieli înregistrate", value: "\(MockData.expenses.count)")
                } header: {
                    Text("Statistici trip")
                }

                // Actions section
                Section {
                    Button(role: .destructive) {
                        // TODO: leave group
                    } label: {
                        Label("Ieși din grup", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profil")
        }
    }
}

// MARK: - Sub-views

struct UserHeaderCard: View {
    let user: GroupMember

    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(user.avatarColor.gradient)
                .frame(width: 80, height: 80)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 6)
                .overlay {
                    Text(user.initials)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                }

            VStack(spacing: 4) {
                Text(user.name)
                    .font(.title2.bold())
                Text("Eu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct GroupInfoRow: View {
    let name: String
    let inviteCode: String
    @State private var codeCopied = false

    var body: some View {
        HStack {
            Label(name, systemImage: "person.3.fill")
                .font(.body)

            Spacer()

            Button {
                UIPasteboard.general.string = inviteCode
                codeCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { codeCopied = false }
            } label: {
                HStack(spacing: 4) {
                    Text(inviteCode)
                        .font(.caption.monospaced())
                    Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .foregroundStyle(codeCopied ? .green : .accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.accentColor.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct MemberListRow: View {
    let member: GroupMember
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(member.avatarColor.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(member.initials)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isCurrentUser ? "\(member.name) (tu)" : member.name)
                        .font(.subheadline)
                        .fontWeight(isCurrentUser ? .bold : .regular)
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(member.isOnline ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(member.isOnline ? "Online" : "Offline")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "battery.50")
                    .font(.caption)
                    .foregroundStyle(member.battery > 20 ? Color.green : Color.red)
                Text("\(member.battery)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.primary)
                .labelStyle(ColoredIconLabelStyle(color: color))
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Custom Label Style

struct ColoredIconLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 7))
            configuration.title
        }
    }
}
