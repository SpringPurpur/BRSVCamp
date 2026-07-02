import SwiftUI
import Supabase

// MARK: - BlogView

struct BlogView: View {
    @Environment(GroupDataStore.self) private var dataStore
    @State private var showCompose = false
    private var posts: [BlogPost] { dataStore.posts }

    var body: some View {
        NavigationStack {
            List {
                ForEach(posts) { post in
                    NavigationLink(destination: BlogPostDetailView(post: post)) {
                        BlogPostRow(post: post)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Blog")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCompose) {
                BlogComposeSheet { showCompose = false }
            }
        }
    }
}

// MARK: - Post Row Card

struct BlogPostRow: View {
    let post: BlogPost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    if let poi = post.poi {
                        HStack(spacing: 5) {
                            Image(systemName: PointOfInterest.pinIcon)
                                .font(.caption)
                            Text(poi.title)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.35), in: Capsule())
                        .padding(10)
                    }
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(post.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(post.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Circle()
                        .fill(post.author.avatarColor.gradient)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Text(post.author.initials)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    Text(post.author.name)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(post.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(.background)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14))
        }
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }

    // Cu 2+ poze, headerul devine un TabView paginat — swipe stânga/dreapta parcurge pozele
    // fără să deschidă postarea (gestul orizontal e capturat de TabView, nu de NavigationLink,
    // care rămâne activ doar pentru un tap simplu). Cu 0-1 poze, rămâne o imagine statică,
    // ca gestul de swipe să nu "fure" din scroll-ul vertical al listei fără niciun beneficiu.
    @ViewBuilder
    private var header: some View {
        if post.photos.count > 1 {
            TabView {
                ForEach(post.photos) { photo in
                    AsyncImage(url: photo.url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.gray.opacity(0.15)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        } else if let firstPhoto = post.photos.first {
            AsyncImage(url: firstPhoto.url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LinearGradient(colors: post.headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        } else {
            LinearGradient(colors: post.headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Post Detail

struct BlogPostDetailView: View {
    let post: BlogPost
    @Environment(\.dismiss) private var dismiss
    @Environment(GroupDataStore.self) private var dataStore
    @Environment(GroupService.self)   private var groupService
    @Environment(AuthService.self)    private var auth

    @State private var fullscreenPhotoURL: URL?
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private var canManage: Bool {
        post.author.id == auth.currentUserId || groupService.activeUserRole == "admin"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header: prima poză dacă există, altfel gradient placeholder
                Group {
                    if let firstPhoto = post.photos.first {
                        AsyncImage(url: firstPhoto.url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            LinearGradient(colors: post.headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { fullscreenPhotoURL = firstPhoto.url }
                    } else {
                        LinearGradient(colors: post.headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .ignoresSafeArea(edges: .top)

                VStack(alignment: .leading, spacing: 16) {
                    // Author + date
                    HStack(spacing: 10) {
                        Circle()
                            .fill(post.author.avatarColor.gradient)
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(post.author.initials)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.author.name)
                                .font(.subheadline.bold())
                            Text(post.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Text(post.title)
                        .font(.title2.bold())

                    if let poi = post.poi {
                        HStack(spacing: 6) {
                            Image(systemName: PointOfInterest.pinIcon)
                                .font(.caption)
                                .foregroundStyle(poi.displayColor)
                            Text(poi.title)
                                .font(.caption.bold())
                                .foregroundStyle(poi.displayColor)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(poi.displayColor.opacity(0.1), in: Capsule())
                    }

                    Text(post.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(5)

                    if post.photos.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(post.photos.dropFirst()) { photo in
                                    AsyncImage(url: photo.url) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Color.gray.opacity(0.15)
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture { fullscreenPhotoURL = photo.url }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(post.title)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            if canManage {
                ToolbarItem(placement: .topBarTrailing) {
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
        }
        .confirmationDialog("Ștergi această postare?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Șterge", role: .destructive) { Task { await deletePost() } }
            Button("Anulează", role: .cancel) {}
        }
        .sheet(isPresented: $showEditSheet) {
            BlogComposeSheet(editing: post) {
                showEditSheet = false
                dismiss()
            }
        }
        .disabled(isDeleting)
        .fullScreenCover(isPresented: Binding(
            get: { fullscreenPhotoURL != nil },
            set: { if !$0 { fullscreenPhotoURL = nil } }
        )) {
            if let url = fullscreenPhotoURL {
                FullScreenImageViewer(url: url)
            }
        }
    }

    private func deletePost() async {
        guard let groupId = groupService.activeGroupId else { return }
        isDeleting = true
        for photo in post.photos {
            _ = try? await supabase.storage.from("blog-photos").remove(paths: [photo.storagePath])
        }
        _ = try? await supabase.from("blog_posts")
            .delete()
            .eq("id", value: post.id.uuidString)
            .execute()
        await dataStore.loadPosts(groupId: groupId)
        dismiss()
    }
}
