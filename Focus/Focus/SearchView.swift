import SwiftUI

struct SearchView: View {
    @Environment(APIClient.self) private var api
    @State private var query = ""
    @State private var isSearching = false
    @FocusState private var isFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal)
                .padding(.vertical, 16)

            // Content
            content
        }
        .background(backgroundGradient)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search your media...", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .font(.title3)
                    .onSubmit { performSearch() }

                if !query.isEmpty {
                    Button {
                        query = ""
                        api.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )

            Button {
                performSearch()
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help("Search")
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isSearching {
            Spacer()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Searching...")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else if api.searchResults.isEmpty && !query.isEmpty {
            Spacer()
            emptyState(icon: "questionmark.magnifyingglass", title: "No Results", subtitle: "Try a different query")
            Spacer()
        } else if !api.searchResults.isEmpty {
            resultsGrid
        } else if api.mediaItems.isEmpty {
            Spacer()
            emptyState(icon: "photo.on.rectangle", title: "No Media Yet", subtitle: "Click Ingest to scan your media folder")
            Spacer()
        } else {
            // Default: show recent/suggested
            recentBrowse
        }
    }

    // MARK: - Results grid

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(api.searchResults) { result in
                    SearchResultCard(result: result)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .animation(.spring(response: 0.4), value: api.searchResults)
    }

    // MARK: - Recent browse (default state)

    private var recentBrowse: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                    Text("Browse All Media")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(api.mediaItems) { item in
                        NavigationLink {
                            MediaDetailView(item: item)
                        } label: {
                            MediaCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.clear, .accentColor.opacity(0.03)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func performSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isSearching = true
        Task {
            try? await api.search(query: q)
            isSearching = false
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let result: SearchResult
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            Group {
                if let nsImage = NSImage(contentsOfFile: result.path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay(Image(systemName: "photo.badge.exclamationmark").font(.title).foregroundStyle(.tertiary))
                }
            }
            .frame(height: 180)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                // Filename + score
                HStack {
                    Text(result.filename)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                        Text(String(format: "%.0f%%", result.score * 100))
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }

                // Description
                Text(result.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .scaleEffect(isHovering ? 1.015 : 1)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3), value: isHovering)
    }
}

// MARK: - Media Card (browse)

struct MediaCard: View {
    let item: MediaItem
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let nsImage = NSImage(contentsOfFile: item.path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay(Image(systemName: "photo.badge.exclamationmark").font(.title).foregroundStyle(.tertiary))
                }
            }
            .frame(height: 180)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        .scaleEffect(isHovering ? 1.015 : 1)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3), value: isHovering)
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environment(APIClient())
}
