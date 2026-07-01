import SwiftUI
import PhotosUI
import Supabase

struct BlogComposeSheet: View {
    enum Mode {
        case create
        case edit(BlogPost)
    }

    let mode: Mode
    var onDone: () -> Void

    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth

    @State private var title: String
    @State private var content: String
    @State private var selectedPOIId: UUID?
    @State private var existingPhotos: [BlogPhoto]
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var photoImages: [UIImage] = []
    @State private var cameraImages: [UIImage] = []
    @State private var showCamera = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Poze noi din galerie + cameră, în ordinea în care apar în preview/upload
    private var newImages: [UIImage] { photoImages + cameraImages }
    private var remainingSlots: Int { max(0, BlogPost.maxPhotos - existingPhotos.count - newImages.count) }

    init(onDone: @escaping () -> Void) {
        self.mode = .create
        self.onDone = onDone
        _title = State(initialValue: "")
        _content = State(initialValue: "")
        _selectedPOIId = State(initialValue: nil)
        _existingPhotos = State(initialValue: [])
    }

    init(editing post: BlogPost, onDone: @escaping () -> Void) {
        self.mode = .edit(post)
        self.onDone = onDone
        _title = State(initialValue: post.title)
        _content = State(initialValue: post.content)
        _selectedPOIId = State(initialValue: post.poi?.id)
        _existingPhotos = State(initialValue: post.photos)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

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

                Section("Fotografii (max \(BlogPost.maxPhotos))") {
                    if remainingSlots > 0 {
                        Menu {
                            PhotosPicker(selection: $photoItems, maxSelectionCount: remainingSlots, matching: .images) {
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
                    }

                    if !existingPhotos.isEmpty || !newImages.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(existingPhotos) { photo in
                                    photoThumbnail(url: photo.url) {
                                        existingPhotos.removeAll { $0.id == photo.id }
                                    }
                                }
                                ForEach(newImages.indices, id: \.self) { idx in
                                    photoThumbnail(image: newImages[idx]) {
                                        removeNewImage(at: idx)
                                    }
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
            .navigationTitle(isEditing ? "Editează postarea" : "Postare nouă")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anulează") { onDone() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Salvează" : "Publică") { Task { await save() } }
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

    private func removeNewImage(at index: Int) {
        if index < photoImages.count {
            photoImages.remove(at: index)
        } else {
            cameraImages.remove(at: index - photoImages.count)
        }
    }

    @ViewBuilder
    private func photoThumbnail(url: URL? = nil, image: UIImage? = nil, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if let url {
                    AsyncImage(url: url) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
        }
    }

    private func save() async {
        guard let userId = auth.currentUserId,
              let groupId = groupService.currentGroup?.id else { return }
        isSaving = true
        errorMessage = nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            switch mode {
            case .create:
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
                    title: trimmedTitle,
                    content: trimmedContent
                )
                struct InsertedPost: Decodable { let id: UUID }
                let inserted: InsertedPost = try await supabase
                    .from("blog_posts")
                    .insert(payload)
                    .select("id")
                    .single()
                    .execute()
                    .value

                try await uploadNewPhotos(postId: inserted.id, groupId: groupId, startingIndex: 0)

            case .edit(let existingPost):
                struct UpdatePost: Encodable {
                    let title: String
                    let content: String
                    let poi_id: UUID?
                }
                try await supabase.from("blog_posts")
                    .update(UpdatePost(title: trimmedTitle, content: trimmedContent, poi_id: selectedPOIId))
                    .eq("id", value: existingPost.id.uuidString)
                    .execute()

                // Șterge (storage + rând) pozele existente pe care userul le-a scos la editare
                let keptIds = Set(existingPhotos.map(\.id))
                let removedPhotos = existingPost.photos.filter { !keptIds.contains($0.id) }
                for photo in removedPhotos {
                    _ = try? await supabase.storage.from("blog-photos").remove(paths: [photo.storagePath])
                    _ = try? await supabase.from("blog_post_photos")
                        .delete()
                        .eq("id", value: photo.id.uuidString)
                        .execute()
                }

                try await uploadNewPhotos(postId: existingPost.id, groupId: groupId, startingIndex: existingPhotos.count)
            }

            await dataStore.loadPosts(groupId: groupId)
            onDone()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    // Nume de fișier unic (nu index secvențial) — la editare, pozele rămase își păstrează
    // path-ul original, deci un index recalculat ar putea coincide cu al unei poze existente.
    private func uploadNewPhotos(postId: UUID, groupId: UUID, startingIndex: Int) async throws {
        for (offset, image) in newImages.enumerated() {
            guard let jpegData = compressedJPEGData(from: image) else { continue }
            let path = "\(groupId.uuidString)/\(postId.uuidString)/\(UUID().uuidString).jpg"
            try await supabase.storage.from("blog-photos")
                .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg"))

            struct NewPhoto: Encodable {
                let post_id: UUID
                let storage_path: String
                let order_index: Int
            }
            try await supabase.from("blog_post_photos")
                .insert(NewPhoto(post_id: postId, storage_path: path, order_index: startingIndex + offset))
                .execute()
        }
    }
}
