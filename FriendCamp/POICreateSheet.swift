import SwiftUI
import MapKit
import PhotosUI
import Supabase

struct POICreateSheet: View {
    enum Mode {
        case create(CLLocationCoordinate2D)
        case edit(PointOfInterest)
    }

    let mode: Mode
    var onDone: () -> Void

    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth

    @State private var title: String
    @State private var description: String
    @State private var category: String
    @State private var selectedColor: Color
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?
    @State private var existingPhotoURL: URL?
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(coordinate: CLLocationCoordinate2D, onDone: @escaping () -> Void) {
        self.mode = .create(coordinate)
        self.onDone = onDone
        _title = State(initialValue: "")
        _description = State(initialValue: "")
        _category = State(initialValue: "")
        _selectedColor = State(initialValue: PointOfInterest.defaultPinColor)
        _existingPhotoURL = State(initialValue: nil)
    }

    init(editing poi: PointOfInterest, onDone: @escaping () -> Void) {
        self.mode = .edit(poi)
        self.onDone = onDone
        _title = State(initialValue: poi.title)
        _description = State(initialValue: poi.description)
        _category = State(initialValue: poi.category)
        _selectedColor = State(initialValue: poi.displayColor)
        _existingPhotoURL = State(initialValue: poi.photoURL)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalii") {
                    TextField("Titlu", text: $title)
                    TextField("ex: Restaurant, Belvedere, Tabără...", text: $category)
                    TextField("Descriere", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    ColorPicker("Culoare pin", selection: $selectedColor, supportsOpacity: false)
                }

                Section("Fotografie") {
                    Menu {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Alege din galerie", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showCamera = true
                        } label: {
                            Label("Fă o poză", systemImage: "camera")
                        }
                    } label: {
                        Label(photoImage == nil ? "Adaugă fotografie" : "Schimbă fotografia",
                              systemImage: "photo")
                    }
                    if let photoImage {
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if let existingPhotoURL {
                        AsyncImage(url: existingPhotoURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.gray.opacity(0.15)
                        }
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(isEditing ? "Editează punct" : "Punct nou")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anulează") { onDone() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salvează") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        photoImage = uiImage
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in photoImage = image }
                    .ignoresSafeArea()
            }
            .disabled(isSaving)
            .overlay {
                if isSaving { ProgressView() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        guard let userId = auth.currentUserId,
              let groupId = groupService.currentGroup?.id else { return }
        isSaving = true
        errorMessage = nil
        let trimmedCategory = category.trimmingCharacters(in: .whitespaces)
        let finalCategory = trimmedCategory.isEmpty ? "Altele" : trimmedCategory
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .create(let coordinate):
                struct NewPOI: Encodable {
                    let group_id: UUID
                    let created_by: UUID
                    let title: String
                    let description: String?
                    let latitude: Double
                    let longitude: Double
                    let category: String
                    let pin_color: String
                }
                let payload = NewPOI(
                    group_id: groupId,
                    created_by: userId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    category: finalCategory,
                    pin_color: selectedColor.toHex()
                )
                let inserted: POIRow = try await supabase
                    .from("points_of_interest")
                    .insert(payload)
                    .select("*, profiles(display_name)")
                    .single()
                    .execute()
                    .value

                if let photoImage, let jpegData = compressedJPEGData(from: photoImage) {
                    let path = "\(groupId.uuidString)/\(inserted.id.uuidString).jpg"
                    try await supabase.storage.from("poi-photos")
                        .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg"))
                    let publicURL = try supabase.storage.from("poi-photos").getPublicURL(path: path)
                    try await supabase.from("points_of_interest")
                        .update(["photo_url": publicURL.absoluteString])
                        .eq("id", value: inserted.id.uuidString)
                        .execute()
                }

            case .edit(let existing):
                struct UpdatePOI: Encodable {
                    let title: String
                    let description: String?
                    let category: String
                    let pin_color: String
                }
                let payload = UpdatePOI(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                    category: finalCategory,
                    pin_color: selectedColor.toHex()
                )
                try await supabase.from("points_of_interest")
                    .update(payload)
                    .eq("id", value: existing.id.uuidString)
                    .execute()

                if let photoImage, let jpegData = compressedJPEGData(from: photoImage) {
                    let path = "\(groupId.uuidString)/\(existing.id.uuidString).jpg"
                    try await supabase.storage.from("poi-photos")
                        .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))
                    let publicURL = try supabase.storage.from("poi-photos").getPublicURL(path: path)
                    try await supabase.from("points_of_interest")
                        .update(["photo_url": publicURL.absoluteString])
                        .eq("id", value: existing.id.uuidString)
                        .execute()
                }
            }

            await dataStore.loadPOIs(groupId: groupId)
            onDone()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
