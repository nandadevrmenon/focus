import Foundation
import Observation

@Observable
final class APIClient {
    private let baseURL = "http://127.0.0.1:8000"
    private let decoder = JSONDecoder()

    var mediaItems: [MediaItem] = []
    var searchResults: [SearchResult] = []
    var isIngesting = false
    var isProcessing = false
    var isLoadingMedia = false
    var isConnected: Bool? = nil
    var hasLoaded = false
    var ingestProgress: Double = 0
    var ingestCurrentFile: String = ""
    var ingestTotal: Int = 0
    var ingestCompleted: Int = 0

    // MARK: - Media

    func fetchMedia() async throws {
        isLoadingMedia = true
        defer { isLoadingMedia = false }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config)
        let url = URL(string: "\(baseURL)/media")!
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let items = try decoder.decode([MediaItem].self, from: data)
        await MainActor.run {
            mediaItems = items
            hasLoaded = true
        }
    }

    func retryFetchMedia() {
        hasLoaded = false
        Task {
            let ok = await waitForServer(timeout: 20)
            if ok { try? await fetchMedia() }
        }
    }

    // MARK: - Search

    func search(query: String, topK: Int = 10) async throws {
        let escaped = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(baseURL)/search?q=\(escaped)&top_k=\(topK)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let results = try decoder.decode([SearchResult].self, from: data)
        await MainActor.run { searchResults = results }
    }

    // MARK: - Health

    func checkConnection() async {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: config)
        let url = URL(string: "\(baseURL)/")!
        do {
            let (_, response) = try await session.data(from: url)
            await MainActor.run {
                isConnected = (response as? HTTPURLResponse)?.statusCode == 200
            }
        } catch {
            await MainActor.run { isConnected = false }
        }
    }

    func waitForServer(timeout: Int = 20) async -> Bool {
        // Always use a fresh session to avoid cached failures
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: config)

        for i in 0..<timeout {
            let url = URL(string: "\(baseURL)/")!
            if let (_, response) = try? await session.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                await MainActor.run { isConnected = true }
                return true
            }
            if i == 0 {
                // Give the server a moment to boot before first retry
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } else {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        await MainActor.run { isConnected = false }
        return false
    }

    // MARK: - Ingest

    func ingest() async throws {
        isIngesting = true
        defer { isIngesting = false }
        let url = URL(string: "\(baseURL)/ingest")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(IngestResponse.self, from: data)
        print("Ingested: \(response.processed) new, \(response.skipped) skipped")
        try await fetchMedia()
    }

    // MARK: - Ingest paths

    func ingestPaths(_ paths: [URL]) async throws {
        isProcessing = true
        ingestProgress = 0
        ingestCurrentFile = "Starting..."

        let url = URL(string: "\(baseURL)/ingest-paths")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = IngestPathsRequest(paths: paths.map { $0.path(percentEncoded: false) })
        request.httpBody = try JSONEncoder().encode(body)

        // Poll progress while request runs
        async let pollTask = pollProgress()
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(IngestResponse.self, from: data)
        _ = await pollTask

        isProcessing = false
        print("Ingested: \(response.processed) new, \(response.skipped) skipped")
        try await fetchMedia()
    }

    private func pollProgress() async {
        while isProcessing {
            do {
                let url = URL(string: "\(baseURL)/ingest-status")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let status = try decoder.decode(IngestStatus.self, from: data)
                await MainActor.run {
                    ingestTotal = status.total
                    ingestCompleted = status.completed
                    ingestCurrentFile = status.currentFile
                    if status.total > 0 {
                        ingestProgress = Double(status.completed) / Double(status.total)
                    }
                }
            } catch {}
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
        await MainActor.run {
            ingestProgress = 1.0
            ingestCurrentFile = ""
        }
    }
}
