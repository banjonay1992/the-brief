import XCTest
@testable import SignalDaily

final class FileBriefingCacheTests: XCTestCase {
    func testCacheRoundTripsLastBriefing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
        let cache = FileBriefingCache(directory: directory)

        try await cache.save(MockData.briefing)
        let loaded = try await cache.loadLastBriefing()

        XCTAssertEqual(loaded, MockData.briefing)
    }
}

