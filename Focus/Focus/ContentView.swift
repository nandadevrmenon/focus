import SwiftUI

struct ContentView: View {
    @Environment(APIClient.self) private var api
    @Environment(ServerManager.self) private var server
    @State private var selectedTab: Tab = .search

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
            switch selectedTab {
            case .search: SearchView()
            case .library: LibraryView()
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    Task { try? await api.ingest() }
                } label: {
                    if api.isIngesting {
                        ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
                    } else {
                        Label("Ingest", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .help("Scan media folder for new files")
                .disabled(api.isIngesting)
            }
        }
        .task { try? await api.fetchMedia() }
    }

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

            // Status indicator
            ConnectionStatusView()
                .padding(.bottom, 12)

            // Server log toggle (debug)
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
}

// MARK: - Connection Status

struct ConnectionStatusView: View {
    @Environment(APIClient.self) private var api
    @Environment(ServerManager.self) private var server

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
                Text(statusText)
                    .font(.caption2)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(tapHelp)
        .onAppear { Task { await api.checkConnection() } }
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
