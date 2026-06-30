import Foundation
import Observation

@Observable
final class ServerManager {
    private var process: Process?
    private var outputPipe: Pipe?

    var isRunning = false
    var log: String = ""

    private let port = 8000

    // Resolve project root relative to this source file's known location
    private var projectRoot: URL {
        // In development (Xcode), working dir is the DerivedData build dir.
        // Walk up from the executable to find the repo root.
        let candidates = [
            URL(fileURLWithPath: "/Users/nanda/Desktop/repos/MediaTag"),
            // Fallback: derive from executable path
            Bundle.main.executableURL?
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent(),
        ]
        for url in candidates.compactMap({ $0 }) {
            let check = url.appendingPathComponent("src/backend/main.py")
            if FileManager.default.fileExists(atPath: check.path) {
                return url
            }
        }
        return candidates.compactMap({ $0 })[0]
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["python3", "-m", "uvicorn", "src.api.main:app", "--port", String(port)]
        task.currentDirectoryURL = projectRoot

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        outputPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                DispatchQueue.main.async {
                    self?.log += text
                }
            }
        }

        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }

        do {
            try task.run()
            process = task
            isRunning = true
            print("Server started at http://127.0.0.1:\(port)")
        } catch {
            log += "Failed to start server: \(error.localizedDescription)\n"
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        print("Server stopped.")
    }

    deinit {
        stop()
    }
}
