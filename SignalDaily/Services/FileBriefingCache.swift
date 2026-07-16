import Foundation

protocol BriefingCaching: Sendable {
    func save(_ briefing: Briefing) async throws
    func loadLastBriefing() async throws -> Briefing?
}

actor FileBriefingCache: BriefingCaching {
    private let fileURL: URL
    private let encoder = SignalJSON.encoder
    private let decoder = SignalJSON.decoder

    init(directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]) {
        self.fileURL = directory.appending(path: "last-briefing.json")
    }

    func save(_ briefing: Briefing) async throws {
        let data = try encoder.encode(briefing)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: [.atomic])
    }

    func loadLastBriefing() async throws -> Briefing? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Briefing.self, from: data)
    }
}

