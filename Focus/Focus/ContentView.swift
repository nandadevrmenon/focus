import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(APIClient.self) private var api
    @Environment(ServerManager.self) private var server
    @State private var selectedTab: Tab = .search
    @State private var showFilePicker = false

    enum Tab: String, CaseIterable, Identifiable {
        case search = "Search"
        case library = "Library"

        var id: Self { self }

        var icon: String {
            switch self {
            case .search: return "magnifyingglass"
            case .library: return "photo.on.rectangle.angled"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 60, ideal: 72, max: 72)
        } detail: {
            ZStack(alignment: .top) {
                if !api.hasLoaded && api.mediaItems.isEmpty {
                    loadingState
                } else if api.hasLoaded && api.mediaItems.isEmpty && !api.isProcessing {
                    emptyState
                } else {
                    switch selectedTab {
                    case .search: SearchView()
                    case .library: LibraryView()
                    }
                }

                // Progress bar banner
                if api.isProcessing {
                    progressBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4), value: api.isProcessing)
        }
        .toolbar { toolbarContent }
        .task {
            // Fallback: wait for server then fetch media
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !api.hasLoaded {
                let ok = await api.waitForServer(timeout: 12)
                if ok { try? await api.fetchMedia() }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder, .jpeg, .png],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    _ = url.startAccessingSecurityScopedResource()
                }
                Task {
                    try? await api.ingestPaths(urls)
                    for url in urls {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Empty state

    // MARK: - Progress banner

    private var progressBanner: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Indexing media...")
                        .font(.subheadline.weight(.medium))
                    if !api.ingestCurrentFile.isEmpty {
                        Text(api.ingestCurrentFile)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if api.ingestTotal > 0 {
                    Text("\(api.ingestCompleted)/\(api.ingestTotal)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            ProgressView(value: api.ingestProgress)
                .tint(.accentColor)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
        .padding()
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }

    // MARK: - Loading state

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Connecting to server...")
                .foregroundStyle(.secondary)
            Button("Retry") {
                server.start()
                api.retryFetchMedia()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Media Yet")
                .font(.title.weight(.semibold))

            Text("Add folders or images to start building\nyour searchable media library.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(4)

            Button {
                showFilePicker = true
            } label: {
                Label("Add Folders or Images", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)

            if api.isProcessing {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing media...")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [.clear, .accentColor.opacity(0.03)], startPoint: .top, endPoint: .bottom))
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 16)

            Spacer()

            ForEach(Tab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon).font(.title3)
                        Text(tab.rawValue).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
            }

            Spacer()

            ConnectionStatusView()
                .padding(.bottom, 12)

            if let log = server.log.split(separator: "\n").last, !log.isEmpty {
                Text(log)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
            }
        }
        .padding(.horizontal, 6)
        .background(.ultraThinMaterial)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showFilePicker = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add folders or images")
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                // TODO: implement refresh functionality later
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh media library")
            .disabled(true) // placeholder — functionality coming later
        }
    }
}

// MARK: - Connection Status

struct ConnectionStatusView: View {
    @Environment(APIClient.self) private var api
    @Environment(ServerManager.self) private var server
    @State private var isHovering = false

    var body: some View {
        Button {
            if api.isConnected == false {
                server.start()
                Task { _ = await api.waitForServer() }
            } else {
                Task { await api.checkConnection() }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 8, height: 8)
                if isHovering {
                    Text(statusText)
                        .font(.caption2)
                        .transition(.opacity)
                }
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(tapHelp)
        .onAppear { Task { await api.checkConnection() } }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private var indicatorColor: Color {
        switch api.isConnected {
        case nil: return .yellow
        case true?: return .green
        case false?: return .red
        }
    }

    private var statusText: String {
        switch api.isConnected {
        case nil: return "Checking..."
        case true?: return "Connected"
        case false?: return "Offline"
        }
    }

    private var tapHelp: String {
        api.isConnected == false ? "Tap to start server" : "Tap to check connection"
    }
}
