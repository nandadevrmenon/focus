import Foundation
import Observation

@Observable
final class APIClient {
    private let baseURL = "http://127.0.0.1:8000"
    private let decoder = JSONDecoder()

    var mediaItems: [MediaItem] = []
    var searchResults: [SearchResult] = []
    var isIngesting = false
    var isLoadingMedia = false
    var isConnected: Bool? = nil

    // MARK: - Media

    func fetchMedia() async throws {
        isLoadingMedia = true
        defer { isLoadingMedia = false }
        let url = URL(string: "\(baseURL)/media")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let items = try decoder.decode([MediaItem].self, from: data)
        await MainActor.run { mediaItems = items }
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
        let url = URL(string: "\(baseURL)/")!
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            await MainActor.run {
                isConnected = (response as? HTTPURLResponse)?.statusCode == 200
            }
        } catch {
            await MainActor.run { isConnected = false }
        }
    }

    func waitForServer(timeout: Int = 15) async -> Bool {
        for _ in 0..<timeout {
            let url = URL(string: "\(baseURL)/")!
            if let (_, response) = try? await URLSession.shared.data(from: url),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                await MainActor.run { isConnected = true }
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
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
}
