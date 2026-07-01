import SwiftUI
import PhotosUI
import Supabase

struct BlogComposeSheet: View {
    var onDone: () -> Void

    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth

    @State private var title = ""
    @State private var content = ""
    @State private var selectedPOIId: UUID?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var cameraImages: [UIImage] = []
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Poze din galerie + poze făcute cu camera, în ordinea în care apar în preview/upload
    private var allImages: [UIImage] { photoImages + cameraImages }

    var body: some View {
        NavigationStack {
            Form {
                Section("Postare") {
                    TextField("Titlu", text: $title)
                    TextField("Conținut", text: $content, axis: .vertical)
                        .lineLimit(6...12)
                }

                Section("Punct de interes (opțional)") {
                    Picker("Leagă de un loc", selection: $selectedPOIId) {
                        Text("Niciunul").tag(UUID?.none)
                        ForEach(dataStore.pois) { poi in
                            Text(poi.title).tag(Optional(poi.id))
                        }
                    }
                }

                Section("Fotografii") {
                    Menu {
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 8, matching: .images) {
                            Label("Alege din galerie", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showCamera = true
                        } label: {
                            Label("Fă o poză", systemImage: "camera")
                        }
                    } label: {
                        Label("Adaugă fotografii", systemImage: "photo")
                    }
                    if !allImages.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(allImages.indices, id: \.self) { idx in
                                    Image(uiImage: allImages[idx])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Postare nouă")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anulează") { onDone() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Publică") { Task { await save() } }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                                  || content.trimmingCharacters(in: .whitespaces).isEmpty
                                  || isSaving)
                }
            }
            .onChange(of: photoItems) { _, newItems in
                Task {
                    var images: [UIImage] = []
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            images.append(img)
                        }
                    }
                    photoImages = images
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in cameraImages.append(image) }
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
        do {
            struct NewPost: Encodable {
                let group_id: UUID
                let author_id: UUID
                let poi_id: UUID?
                let title: String
                let content: String
            }
            let payload = NewPost(
                group_id: groupId,
                author_id: userId,
                poi_id: selectedPOIId,
                title: title.trimmingCharacters(in: .whitespaces),
                content: content.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            struct InsertedPost: Decodable { let id: UUID }
            let inserted: InsertedPost = try await supabase
                .from("blog_posts")
                .insert(payload)
                .select("id")
                .single()
                .execute()
                .value

            for (index, image) in allImages.enumerated() {
                guard let jpegData = compressedJPEGData(from: image) else { continue }
                let path = "\(groupId.uuidString)/\(inserted.id.uuidString)/\(index).jpg"
                try await supabase.storage.from("blog-photos")
                    .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg"))

                struct NewPhoto: Encodable {
                    let post_id: UUID
                    let storage_path: String
                    let order_index: Int
                }
                try await supabase.from("blog_post_photos")
                    .insert(NewPhoto(post_id: inserted.id, storage_path: path, order_index: index))
                    .execute()
            }

            await dataStore.loadPosts(groupId: groupId)
            onDone()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}
