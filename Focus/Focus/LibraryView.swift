import SwiftUI

struct LibraryView: View {
    @Environment(APIClient.self) private var api
    @State private var selectedItem: MediaItem?
    @State private var sortOrder: SortOrder = .recent

    enum SortOrder: String, CaseIterable {
        case recent = "Recent"
        case name = "Name"
        case type = "Type"

        var systemImage: String {
            switch self {
            case .recent: "clock"
            case .name: "textformat"
            case .type: "doc"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            listSidebar
            detailPane
        }
    }

    // MARK: - List sidebar

    private var listSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Media Library")
                    .font(.title3.weight(.semibold))
                Spacer()
                Picker("Sort", selection: $sortOrder) {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Label(order.rawValue, systemImage: order.systemImage).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)

            // List
            List(selection: $selectedItem) {
                ForEach(sortedItems) { item in
                    LibraryRow(item: item)
                        .tag(item)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedItem?.id == item.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(minWidth: 280, idealWidth: 320)
        .background(.background)
    }

    // MARK: - Detail pane

    @ViewBuilder
    private var detailPane: some View {
        if let item = selectedItem {
            MediaDetailView(item: item)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("Select an item to view")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundGradient)
        }
    }

    // MARK: - Helpers

    private var sortedItems: [MediaItem] {
        switch sortOrder {
        case .recent: api.mediaItems
        case .name: api.mediaItems.sorted { $0.path < $1.path }
        case .type: api.mediaItems.sorted { $0.type < $1.type }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.clear, .accentColor.opacity(0.03)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Library Row

struct LibraryRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            Group {
                let imagePath = item.thumbnailPath.isEmpty ? item.path : item.thumbnailPath
                if let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                }
            }
            .frame(width: 44, height: 44)
            .clipped()
            .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: item.path).lastPathComponent)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Type badge
            Text(item.type.uppercased())
                .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
        .environment(APIClient())
}
