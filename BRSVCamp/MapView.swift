import SwiftUI
import MapKit
import Observation

// MARK: - ViewModel

@Observable
final class MapViewModel {
    var members = MockData.members
    var pois = MockData.pois
    var selectedMember: GroupMember?
    var selectedPOI: PointOfInterest?
    var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.9440, longitude: 24.9675),
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
    )
}

// MARK: - MapView

struct MapView: View {
    @State private var vm = MapViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $vm.cameraPosition) {
                    ForEach(vm.members) { member in
                        Annotation(member.name, coordinate: member.coordinate, anchor: .bottom) {
                            MemberMapPin(member: member)
                                .onTapGesture { vm.selectedMember = member }
                        }
                    }
                    ForEach(vm.pois) { poi in
                        Annotation(poi.title, coordinate: poi.coordinate, anchor: .bottom) {
                            POIMapPin(poi: poi)
                                .onTapGesture { vm.selectedPOI = poi }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .top)

                MemberStatusBar(members: vm.members) { member in
                    vm.selectedMember = member
                }
            }
            .navigationTitle("BRSVCamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // TODO: add POI
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
        .sheet(item: $vm.selectedMember) { member in
            MemberDetailSheet(member: member)
        }
        .sheet(item: $vm.selectedPOI) { poi in
            POIDetailSheet(poi: poi)
        }
    }
}

// MARK: - Map Pins

struct MemberMapPin: View {
    let member: GroupMember

    var body: some View {
        ZStack {
            Circle()
                .fill(member.avatarColor.gradient)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Text(member.initials)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(member.isOnline ? Color.green : Color.gray)
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .offset(x: 2, y: 2)
        }
    }
}

struct POIMapPin: View {
    let poi: PointOfInterest

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemBackground))
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            Image(systemName: poi.category.systemImage)
                .font(.system(size: 17))
                .foregroundStyle(poi.category.color)
        }
    }
}

// MARK: - Member Status Bar

struct MemberStatusBar: View {
    let members: [GroupMember]
    let onTap: (GroupMember) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(members) { member in
                    MemberChip(member: member)
                        .onTapGesture { onTap(member) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }
}

struct MemberChip: View {
    let member: GroupMember

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(member.avatarColor.gradient)
                .frame(width: 32, height: 32)
                .overlay {
                    Text(member.initials)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(member.isOnline ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)
                    Text(member.isOnline ? "Live" : timeAgo(member.lastSeen))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 2) {
                Image(systemName: batteryIcon(member.battery))
                    .font(.caption2)
                    .foregroundStyle(member.battery > 20 ? Color.green : Color.red)
                Text("\(member.battery)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }

    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        default:       return "battery.25"
        }
    }
}

// MARK: - Detail Sheets

struct MemberDetailSheet: View {
    let member: GroupMember
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Circle()
                    .fill(member.avatarColor.gradient)
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(radius: 8)
                    .overlay {
                        Text(member.initials)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text(member.name)
                    .font(.title.bold())

                HStack(spacing: 32) {
                    DetailStat(
                        icon: "circle.fill",
                        iconColor: member.isOnline ? .green : .gray,
                        label: member.isOnline ? "Online" : "Offline",
                        value: member.isOnline ? "Live" : timeAgo(member.lastSeen)
                    )
                    DetailStat(
                        icon: batteryIcon(member.battery),
                        iconColor: member.battery > 20 ? .green : .red,
                        label: "Baterie",
                        value: "\(member.battery)%"
                    )
                }

                Spacer()
            }
            .padding(.top, 32)
            .padding(.horizontal)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Închide") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(-date.timeIntervalSinceNow / 60)
        return minutes < 60 ? "acum \(minutes)m" : "acum \(minutes / 60)h"
    }

    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 76...100: return "battery.100"
        case 51...75:  return "battery.75"
        case 26...50:  return "battery.50"
        default:       return "battery.25"
        }
    }
}

struct POIDetailSheet: View {
    let poi: PointOfInterest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: poi.category.systemImage)
                        .font(.title2)
                        .foregroundStyle(poi.category.color)
                        .frame(width: 44, height: 44)
                        .background(poi.category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(poi.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(poi.title)
                            .font(.headline)
                    }
                }

                Divider()

                Text(poi.description)
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack {
                    Image(systemName: "person.circle")
                        .foregroundStyle(.secondary)
                    Text("Adăugat de \(poi.createdBy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(poi.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Închide") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Helpers

struct DetailStat: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }
}
