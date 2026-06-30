import Foundation

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let path: String
    let type: String
    let description: String
    let tags: String
    let thumbnailPath: String
}

struct SearchResult: Codable, Identifiable, Equatable {
    let score: Double
    let path: String
    let filename: String
    let description: String
    let thumbnailPath: String

    var id: String { filename }
}

struct IngestStatus: Codable {
    let isProcessing: Bool
    let total: Int
    let completed: Int
    let currentFile: String
}

struct IngestResponse: Codable {
    let message: String
    let processed: Int
    let skipped: Int
}

struct IngestPathsRequest: Codable {
    let paths: [String]
}
