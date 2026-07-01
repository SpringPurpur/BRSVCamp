import SwiftUI

// MARK: - BlogView

struct BlogView: View {
    @Environment(GroupDataStore.self) private var dataStore
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
                        // TODO: new post
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
        }
    }
}

// MARK: - Post Row Card

struct BlogPostRow: View {
    let post: BlogPost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header gradient (placeholder pentru foto)
            LinearGradient(colors: post.headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 120)
                .overlay(alignment: .bottomLeading) {
                    if let poi = post.poi {
                        HStack(spacing: 5) {
                            Image(systemName: poi.category.systemImage)
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
}

// MARK: - Post Detail

struct BlogPostDetailView: View {
    let post: BlogPost

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                LinearGradient(colors: post.headerColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 220)
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
                            Image(systemName: poi.category.systemImage)
                                .font(.caption)
                                .foregroundStyle(poi.category.color)
                            Text(poi.title)
                                .font(.caption.bold())
                                .foregroundStyle(poi.category.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(poi.category.color.opacity(0.1), in: Capsule())
                    }

                    Text(post.content)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(5)
                }
                .padding(20)
            }
        }
        .navigationTitle(post.title)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .top)
    }
}
