import XCTest
@testable import SignalDaily

@MainActor
final class PersistenceStoreTests: XCTestCase {
    func testPreferencesPersistToUserDefaults() async {
        let defaults = UserDefaults(suiteName: "PreferencesStoreTests-\(UUID().uuidString)")!
        let key = "preferences"
        let store = PreferencesStore(
            preferences: .defaults,
            service: GraphicMockService(),
            userDefaults: defaults,
            storageKey: key
        )

        store.preferences.maxStories = 12
        await store.save()

        let restored = PreferencesStore(service: GraphicMockService(), userDefaults: defaults, storageKey: key)
        XCTAssertEqual(restored.preferences.maxStories, 12)
    }

    func testSavedStoriesTogglePersistsIDs() {
        let defaults = UserDefaults(suiteName: "SavedStoriesStoreTests-\(UUID().uuidString)")!
        let key = "saved"
        let store = SavedStoriesStore(userDefaults: defaults, storageKey: key)

        store.toggle("story_001")
        XCTAssertTrue(store.contains("story_001"))

        let restored = SavedStoriesStore(userDefaults: defaults, storageKey: key)
        XCTAssertEqual(restored.savedStoryIDs, ["story_001"])

        restored.toggle("story_001")
        XCTAssertFalse(restored.contains("story_001"))
    }

    func testSavedStoriesPersistCompactSnapshotsForExpiredFeedItems() {
        let defaults = UserDefaults(suiteName: "SavedStoriesSnapshotTests-\(UUID().uuidString)")!
        let key = "saved"
        let story = StorySummary(
            id: "story_saved",
            publishedAt: ISO8601DateFormatter().date(from: "2026-05-18T12:00:00Z"),
            expiresAt: ISO8601DateFormatter().date(from: "2026-05-21T12:00:00Z"),
            headline: "Saved story",
            region: "World",
            category: "World",
            summary: "A compact summary survives feed expiry.",
            whyItMatters: "The user chose to keep it.",
            confidence: .medium,
            emotionalLoad: .low,
            sourceCount: 2,
            imageId: nil
        )
        let store = SavedStoriesStore(userDefaults: defaults, storageKey: key)

        store.toggle(story, savedAt: ISO8601DateFormatter().date(from: "2026-05-18T13:00:00Z")!)

        let restored = SavedStoriesStore(userDefaults: defaults, storageKey: key)
        XCTAssertEqual(restored.savedStoryIDs, ["story_saved"])
        XCTAssertEqual(restored.snapshot(id: "story_saved")?.story.headline, "Saved story")
    }
}
