import Foundation

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let path: String
    let type: String
    let description: String
    let tags: String
}

struct SearchResult: Codable, Identifiable, Equatable {
    let score: Double
    let path: String
    let filename: String
    let description: String

    var id: String { filename }
}

struct IngestResponse: Codable {
    let message: String
    let processed: Int
    let skipped: Int
}
