import SwiftUI

struct MediaDetailView: View {
    let item: MediaItem
    @State private var isHoveringImage = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero image
                heroImage

                // Info panel
                infoPanel
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
        .scrollContentBackground(.hidden)
        .background(backgroundGradient)
        .navigationTitle(URL(fileURLWithPath: item.path).lastPathComponent)
    }

    // MARK: - Hero image

    private var heroImage: some View {
        Group {
            if let nsImage = NSImage(contentsOfFile: item.path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
                    .scaleEffect(isHoveringImage ? 1.02 : 1)
                    .onHover { isHoveringImage = $0 }
                    .animation(.spring(response: 0.4), value: isHoveringImage)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(height: 400)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("Image not found at path")
                                .foregroundStyle(.secondary)
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }
        }
    }

    // MARK: - Info panel

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(URL(fileURLWithPath: item.path).lastPathComponent)
                        .font(.title.weight(.semibold))

                    HStack(spacing: 8) {
                        Label(item.type.uppercased(), systemImage: "doc")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Color.accentColor)

                        Text("\(Int(item.description.split(separator: " ").count)) words")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Quick actions
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                    } label: {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.accessoryBar)
                }
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.secondary)
                    Text("Description")
                        .font(.headline)
                }

                Text(item.description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            }

            // Tags (if any)
            if !item.tags.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        Text("Tags")
                            .font(.headline)
                    }

                    HStack(spacing: 6) {
                        ForEach(item.tags.split(separator: ","), id: \.self) { tag in
                            Text(tag.trimmingCharacters(in: .whitespaces))
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [.clear, .accentColor.opacity(0.03), .accentColor.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#Preview {
    MediaDetailView(item: MediaItem(
        id: "preview",
        path: "/Users/nanda/Desktop/repos/MediaTag/media/DSC06912.jpg",
        type: "jpg",
        description: "A preview image description showing the detail view layout with glass materials and modern typography.",
        tags: "preview, demo, sample"
    ))
}
