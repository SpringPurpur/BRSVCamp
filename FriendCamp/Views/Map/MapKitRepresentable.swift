import SwiftUI
import MapKit
import MapCache

// MARK: - Annotations

// `@objc dynamic coordinate` (nu doar `var`) e obligatoriu — e felul în care MapKit observă
// prin KVO mutarea unui pin și îl animă spre noua poziție, în loc să-l teleporteze.
final class MemberAnnotation: NSObject, MKAnnotation {
    let id: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var member: GroupMember
    var ringColor: Color

    var title: String? { member.name }

    init(member: GroupMember, ringColor: Color) {
        self.id = member.id
        self.coordinate = member.coordinate
        self.member = member
        self.ringColor = ringColor
    }

    func update(member: GroupMember, ringColor: Color) {
        self.member = member
        self.ringColor = ringColor
        if coordinate.latitude != member.coordinate.latitude || coordinate.longitude != member.coordinate.longitude {
            coordinate = member.coordinate
        }
    }
}

final class POIAnnotation: NSObject, MKAnnotation {
    let id: UUID
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var poi: PointOfInterest

    var title: String? { poi.title }

    init(poi: PointOfInterest) {
        self.id = poi.id
        self.coordinate = poi.coordinate
        self.poi = poi
    }

    func update(poi: PointOfInterest) {
        self.poi = poi
        if coordinate.latitude != poi.coordinate.latitude || coordinate.longitude != poi.coordinate.longitude {
            coordinate = poi.coordinate
        }
    }
}

// MARK: - SwiftUI content hosted inside a MKAnnotationView

// Găzduiește un view SwiftUI (MemberMapPin/POIMapPin, neschimbate) într-un MKAnnotationView.
// Nu se poate folosi UIHostingConfiguration aici — funcționează doar pe celule de
// tabel/collection, nu pe MKAnnotationView.
final class HostingAnnotationView<Content: View>: MKAnnotationView {
    private var hostingController: UIHostingController<Content>?

    func setContent(_ content: Content) {
        if let hostingController {
            hostingController.rootView = content
        } else {
            let controller = UIHostingController(rootView: content)
            controller.view.backgroundColor = .clear
            addSubview(controller.view)
            hostingController = controller
        }
        guard let hostingController else { return }
        let size = hostingController.sizeThatFits(in: CGSize(width: 200, height: 200))
        let frame = CGRect(origin: .zero, size: size)
        hostingController.view.frame = frame
        self.frame = frame
        // Ancorează BAZA pinului pe coordonată — echivalentul lui `anchor: .bottom`
        // din fostul `Annotation` SwiftUI.
        centerOffset = CGPoint(x: 0, y: -size.height / 2)
    }
}

// MARK: - MapKitMapView

struct MapKitMapView: UIViewRepresentable {
    let members: [GroupMember]
    let pois: [PointOfInterest]
    let isMultiGroup: Bool
    let mapCache: MapCache
    @Binding var centerRequest: CLLocationCoordinate2D?
    let onSelectMember: (GroupMember) -> Void
    let onSelectPOI: (PointOfInterest) -> Void
    let onRegionChange: (MKCoordinateRegion) -> Void

    private static let initialRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 45.9440, longitude: 24.9675),
        span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
    )

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        // Userul propriu apare deja ca pin din group_member_status, ca înainte — nu mai
        // adăugăm și bulina albastră nativă a MapKit.
        mapView.showsUserLocation = false
        // Tile-uri raster plate (OSM) — un tilt 3D nu ar avea niciun conținut de arătat.
        mapView.isPitchEnabled = false
        mapView.useCache(mapCache)
        mapView.setRegion(Self.initialRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncAnnotations(on: mapView)
        if let coord = centerRequest {
            let region = MKCoordinateRegion(center: coord, span: mapView.region.span)
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async { centerRequest = nil }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitMapView
        private var memberAnnotations: [UUID: MemberAnnotation] = [:]
        private var poiAnnotations: [UUID: POIAnnotation] = [:]

        init(_ parent: MapKitMapView) {
            self.parent = parent
        }

        // Diff pe id, nu remove-all/add-all — anotările existente doar își actualizează
        // coordonata (animat) și conținutul găzduit, ca să nu "clipească" la fiecare poll.
        func syncAnnotations(on mapView: MKMapView) {
            syncMembers(on: mapView)
            syncPOIs(on: mapView)
        }

        private func syncMembers(on mapView: MKMapView) {
            let currentIds = Set(parent.members.map(\.id))
            for staleId in Set(memberAnnotations.keys).subtracting(currentIds) {
                if let annotation = memberAnnotations.removeValue(forKey: staleId) {
                    mapView.removeAnnotation(annotation)
                }
            }
            for member in parent.members {
                let ringColor = parent.isMultiGroup ? member.groupId.groupAccentColor : .white
                if let existing = memberAnnotations[member.id] {
                    existing.update(member: member, ringColor: ringColor)
                    if let view = mapView.view(for: existing) as? HostingAnnotationView<MemberMapPin> {
                        view.setContent(MemberMapPin(member: member, ringColor: ringColor))
                    }
                } else {
                    let annotation = MemberAnnotation(member: member, ringColor: ringColor)
                    memberAnnotations[member.id] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }

        private func syncPOIs(on mapView: MKMapView) {
            let currentIds = Set(parent.pois.map(\.id))
            for staleId in Set(poiAnnotations.keys).subtracting(currentIds) {
                if let annotation = poiAnnotations.removeValue(forKey: staleId) {
                    mapView.removeAnnotation(annotation)
                }
            }
            for poi in parent.pois {
                if let existing = poiAnnotations[poi.id] {
                    existing.update(poi: poi)
                    if let view = mapView.view(for: existing) as? HostingAnnotationView<POIMapPin> {
                        view.setContent(POIMapPin(poi: poi))
                    }
                } else {
                    let annotation = POIAnnotation(poi: poi)
                    poiAnnotations[poi.id] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            mapView.mapCacheRenderer(forOverlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let memberAnnotation = annotation as? MemberAnnotation {
                let identifier = "member"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? HostingAnnotationView<MemberMapPin>)
                    ?? HostingAnnotationView<MemberMapPin>(annotation: memberAnnotation, reuseIdentifier: identifier)
                view.annotation = memberAnnotation
                view.canShowCallout = false
                view.setContent(MemberMapPin(member: memberAnnotation.member, ringColor: memberAnnotation.ringColor))
                return view
            }
            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "poi"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? HostingAnnotationView<POIMapPin>)
                    ?? HostingAnnotationView<POIMapPin>(annotation: poiAnnotation, reuseIdentifier: identifier)
                view.annotation = poiAnnotation
                view.canShowCallout = false
                view.setContent(POIMapPin(poi: poiAnnotation.poi))
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // Nu folosim highlight-ul nativ de selecție — un tap deschide direct un sheet.
            defer { mapView.deselectAnnotation(annotation, animated: false) }
            if let memberAnnotation = annotation as? MemberAnnotation {
                parent.onSelectMember(memberAnnotation.member)
            } else if let poiAnnotation = annotation as? POIAnnotation {
                parent.onSelectPOI(poiAnnotation.poi)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }
    }
}
