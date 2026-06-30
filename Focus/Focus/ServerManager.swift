import Foundation
import Observation

@Observable
final class ServerManager {
    private var process: Process?
    private var readTask: Task<Void, Never>?

    var isRunning = false
    var log: String = ""

    private let port = 8000
    private let projectRoot = "/Users/nanda/Desktop/repos/MediaTag"

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [
            "-c",
            "cd '\(projectRoot)' && exec /usr/bin/python3 -m uvicorn src.api.main:app --port \(port)"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.terminationHandler = { [weak self] task in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.log += "[exited code \(task.terminationStatus)]\n"
            }
        }

        do {
            try task.run()
            process = task
            isRunning = true
            log += "Starting server...\n"

            // Read output asynchronously
            readTask = Task { [weak self] in
                let handle = pipe.fileHandleForReading
                while !Task.isCancelled {
                    let data = handle.availableData
                    if data.isEmpty { break }
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        await MainActor.run { self?.log += text }
                    }
                }
            }
        } catch {
            log += "Failed: \(error.localizedDescription)\n"
        }
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        process?.terminate()
        process = nil
        isRunning = false
    }

    deinit {
        stop()
    }
}
