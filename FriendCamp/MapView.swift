import SwiftUI
import MapKit
import Observation
import Supabase

// MARK: - ViewModel (UI state only — date reale vin din GroupDataStore)

@Observable
final class MapViewModel {
    var selectedMember: GroupMember?
    var selectedPOI: PointOfInterest?
    var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.9440, longitude: 24.9675),
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
    )
    // Plasare POI: userul apasă +, apoi atinge harta pentru a alege poziția
    var isPlacingPOI = false
    var pendingPOICoordinate: CLLocationCoordinate2D?
}

// MARK: - MapView

struct MapView: View {
    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth
    @Environment(UserPreferencesService.self) private var prefs

    @State private var vm = MapViewModel()
    @State private var locationService = LocationService()
    @State private var hasCenteredOnUser = false
    // Urmărit continuu cât timp harta e vizibilă, ca la activarea modului de plasare
    // să existe deja o coordonată validă fără să aștepte primul eveniment de cameră.
    @State private var mapCenterCoordinate = CLLocationCoordinate2D(latitude: 45.9440, longitude: 24.9675)

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $vm.cameraPosition) {
                    ForEach(dataStore.members) { member in
                        Annotation(member.name, coordinate: member.coordinate, anchor: .bottom) {
                            MemberMapPin(member: member)
                                .onTapGesture { vm.selectedMember = member }
                        }
                    }
                    ForEach(dataStore.pois) { poi in
                        Annotation(poi.title, coordinate: poi.coordinate, anchor: .bottom) {
                            POIMapPin(poi: poi)
                                .onTapGesture { vm.selectedPOI = poi }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onMapCameraChange(frequency: .continuous) { context in
                    mapCenterCoordinate = context.region.center
                }
                .ignoresSafeArea(edges: .top)
                .onAppear { locationService.requestPermission() }
                .onChange(of: locationService.hasLocation) { _, hasLocation in
                    guard hasLocation, !hasCenteredOnUser,
                          let coord = locationService.userLocation else { return }
                    hasCenteredOnUser = true
                    withAnimation {
                        vm.cameraPosition = .region(MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                        ))
                    }
                }
                .onChange(of: locationService.userLocation) { _, _ in
                    Task { await uploadHeartbeat() }
                }

                if vm.isPlacingPOI {
                    Image(systemName: PointOfInterest.pinIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(PointOfInterest.defaultPinColor)
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: -20)

                    PlacingPOIConfirmBar(
                        onCancel: { vm.isPlacingPOI = false },
                        onConfirm: {
                            vm.pendingPOICoordinate = mapCenterCoordinate
                            vm.isPlacingPOI = false
                        }
                    )
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                } else {
                    MemberStatusBar(members: dataStore.members) { member in
                        vm.selectedMember = member
                    }
                }
            }
            .navigationTitle("FriendCamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        guard let coord = locationService.userLocation else { return }
                        withAnimation {
                            vm.cameraPosition = .region(MKCoordinateRegion(
                                center: coord,
                                span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                            ))
                        }
                    } label: {
                        Image(systemName: locationService.hasLocation
                              ? "location.fill" : "location.slash")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.isPlacingPOI.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(vm.isPlacingPOI ? Color.orange : Color.accentColor)
                    }
                }
            }
        }
        // Polling membri la fiecare 15s — fallback dacă Realtime pică (reconectare, background)
        .task(id: groupService.currentGroup?.id) {
            guard let groupId = groupService.currentGroup?.id else { return }
            await dataStore.pollMembers(groupId: groupId)
        }
        // Realtime — actualizează membrii aproape instant la orice update de locație
        .task(id: groupService.currentGroup?.id) {
            guard let groupId = groupService.currentGroup?.id else { return }
            await dataStore.subscribeToLocationUpdates(groupId: groupId)
        }
        // Heartbeat: retrimite locația + bateria la fiecare 20s, chiar dacă userul stă pe loc,
        // altfel is_online/bateria rămân înghețate la ultima valoare din momentul primului fix GPS.
        .task(id: groupService.currentGroup?.id) {
            while !Task.isCancelled {
                await uploadHeartbeat()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        .sheet(item: $vm.selectedMember) { member in
            MemberDetailSheet(member: member)
        }
        .sheet(item: $vm.selectedPOI) { poi in
            POIDetailSheet(poi: poi)
        }
        .sheet(isPresented: Binding(
            get: { vm.pendingPOICoordinate != nil },
            set: { if !$0 { vm.pendingPOICoordinate = nil } }
        )) {
            if let coordinate = vm.pendingPOICoordinate {
                POICreateSheet(coordinate: coordinate) { vm.pendingPOICoordinate = nil }
            }
        }
    }

    private func uploadHeartbeat() async {
        guard let coord = locationService.userLocation,
              prefs.preferences.shareLocation,
              let userId = auth.currentUserId,
              let groupId = groupService.currentGroup?.id else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = UIDevice.current.batteryLevel
        let batteryPct = battery >= 0 ? Int(battery * 100) : nil
        await dataStore.uploadLocation(userId: userId, groupId: groupId,
                                        coordinate: coord, batteryPercent: batteryPct)
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
            Image(systemName: PointOfInterest.pinIcon)
                .font(.system(size: 17))
                .foregroundStyle(poi.displayColor)
        }
    }
}

struct PlacingPOIConfirmBar: View {
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Anulează", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
            Button("Confirmă", action: onConfirm)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        .padding(.horizontal)
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
    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showFullscreenPhoto = false
    @State private var isDeleting = false

    private var canManage: Bool {
        poi.createdById == auth.currentUserId || groupService.currentUserRole == "admin"
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: PointOfInterest.pinIcon)
                        .font(.title2)
                        .foregroundStyle(poi.displayColor)
                        .frame(width: 44, height: 44)
                        .background(poi.displayColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(poi.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(poi.title)
                            .font(.headline)
                    }
                }

                if let photoURL = poi.photoURL {
                    AsyncImage(url: photoURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture { showFullscreenPhoto = true }
                    .fullScreenCover(isPresented: $showFullscreenPhoto) {
                        FullScreenImageViewer(url: photoURL)
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
                if canManage {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button("Editează", systemImage: "pencil") { showEditSheet = true }
                            Button("Șterge", systemImage: "trash", role: .destructive) {
                                showDeleteConfirm = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Închide") { dismiss() }
                }
            }
            .confirmationDialog("Ștergi acest punct?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Șterge", role: .destructive) { Task { await deletePOI() } }
                Button("Anulează", role: .cancel) {}
            }
            .sheet(isPresented: $showEditSheet) {
                POICreateSheet(editing: poi) {
                    showEditSheet = false
                    dismiss()
                }
            }
            .disabled(isDeleting)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func deletePOI() async {
        guard let groupId = groupService.currentGroup?.id else { return }
        isDeleting = true
        if poi.photoURL != nil {
            let path = "\(groupId.uuidString)/\(poi.id.uuidString).jpg"
            _ = try? await supabase.storage.from("poi-photos").remove(paths: [path])
        }
        _ = try? await supabase.from("points_of_interest")
            .delete()
            .eq("id", value: poi.id.uuidString)
            .execute()
        await dataStore.loadPOIs(groupId: groupId)
        dismiss()
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
