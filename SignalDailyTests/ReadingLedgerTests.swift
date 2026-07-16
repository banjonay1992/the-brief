import XCTest
@testable import SignalDaily

@MainActor
final class ReadingLedgerTests: XCTestCase {
    private func makeStory(id: String) -> StorySummary {
        StorySummary(
            id: id,
            headline: "Headline \(id)",
            region: "World",
            category: "World",
            summary: "Summary",
            whyItMatters: "Why",
            confidence: .medium,
            emotionalLoad: .low,
            sourceCount: 2,
            imageId: nil
        )
    }

    private func makeLedger(suite: String = UUID().uuidString) -> (ReadingLedger, UserDefaults) {
        let defaults = UserDefaults(suiteName: "ReadingLedgerTests-\(suite)")!
        return (ReadingLedger(userDefaults: defaults, storageKey: "ledger"), defaults)
    }

    func testRecordReadPersistsAndDeduplicates() {
        let (ledger, defaults) = makeLedger()
        let story = makeStory(id: "story_001")

        ledger.recordRead(story, briefingDate: "2026-07-16")
        ledger.recordRead(story, briefingDate: "2026-07-16")

        XCTAssertEqual(ledger.totalReadCount, 1)

        let restored = ReadingLedger(userDefaults: defaults, storageKey: "ledger")
        XCTAssertEqual(restored.totalReadCount, 1)
        XCTAssertEqual(restored.readStoryIDs(briefingDate: "2026-07-16"), ["story_001"])
    }

    func testRecordsGroupNewestDayFirst() {
        let (ledger, _) = makeLedger()

        ledger.recordRead(makeStory(id: "a"), briefingDate: "2026-07-14")
        ledger.recordRead(makeStory(id: "b"), briefingDate: "2026-07-16")
        ledger.recordRead(makeStory(id: "c"), briefingDate: "2026-07-16")

        let days = ledger.recordsByDay
        XCTAssertEqual(days.map(\.date), ["2026-07-16", "2026-07-14"])
        XCTAssertEqual(days.first?.records.map(\.id), ["b", "c"])
        XCTAssertEqual(ledger.readingDayCount, 2)
    }

    func testCalmMorningsAreIdempotentPerDay() {
        let (ledger, defaults) = makeLedger()

        ledger.recordCompletedMorning(briefingDate: "2026-07-15")
        ledger.recordCompletedMorning(briefingDate: "2026-07-15")
        ledger.recordCompletedMorning(briefingDate: "2026-07-16")

        XCTAssertEqual(ledger.calmMorningCount, 2)

        let restored = ReadingLedger(userDefaults: defaults, storageKey: "ledger")
        XCTAssertEqual(restored.calmMorningCount, 2)
    }

    func testThreadDayNumberCountsFromFirstSighting() {
        let (ledger, _) = makeLedger()
        let story = makeStory(id: "story_thread")

        ledger.noteSeen(stories: [story], briefingDate: "2026-07-14")
        ledger.noteSeen(stories: [story], briefingDate: "2026-07-16")

        XCTAssertEqual(ledger.threadDayNumber(storyID: "story_thread", briefingDate: "2026-07-14"), 1)
        XCTAssertEqual(ledger.threadDayNumber(storyID: "story_thread", briefingDate: "2026-07-16"), 3)
        XCTAssertNil(ledger.threadDayNumber(storyID: "unknown", briefingDate: "2026-07-16"))
    }
}
