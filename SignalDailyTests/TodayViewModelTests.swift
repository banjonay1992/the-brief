import XCTest
@testable import SignalDaily

@MainActor
final class TodayViewModelTests: XCTestCase {
    func testLowIntensityModeFiltersGraphicStories() async {
        let viewModel = TodayViewModel(service: GraphicMockService(), cache: NoopBriefingCache())
        viewModel.selectedMode = .lowIntensity

        await viewModel.loadToday()

        XCTAssertEqual(viewModel.briefing?.storyCount, 1)
        XCTAssertEqual(viewModel.briefing?.allStories.map(\.emotionalLoad), [.low])
    }

    func testProgressOnlyModeKeepsLowIntensityStoriesOnly() async {
        let viewModel = TodayViewModel(service: GraphicMockService(), cache: NoopBriefingCache())
        viewModel.selectedMode = .progressOnly

        await viewModel.loadToday()

        XCTAssertEqual(viewModel.briefing?.title, "Progress Briefing")
        XCTAssertEqual(viewModel.briefing?.allStories.count, 1)
    }

    func testReadProgressCountsOpenedStories() async {
        let viewModel = TodayViewModel(service: GraphicMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()
        viewModel.markRead("low")

        XCTAssertEqual(viewModel.readProgressText, "1/2 read")
    }

    func testLoadTodayFetchesFiniteCalmUpdates() async {
        let viewModel = TodayViewModel(service: GraphicMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()

        XCTAssertEqual(viewModel.updates?.updates.count, 1)
        XCTAssertEqual(viewModel.updates?.updates.first?.isCritical, false)
    }

    func testStoryQueuePutsUpdatedStoriesFirst() async {
        let viewModel = TodayViewModel(service: GraphicMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()

        XCTAssertEqual(viewModel.storyQueue.map(\.id), ["graphic", "low"])
    }

    func testMarkReadRemovesStoryFromQueue() async {
        let viewModel = TodayViewModel(service: GraphicMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()
        viewModel.markRead("graphic")

        XCTAssertEqual(viewModel.storyQueue.map(\.id), ["low"])
        XCTAssertEqual(viewModel.readProgressText, "1/2 read")
    }

    func testSubscriptionPromptStartsAfterTenReadStoriesForUnsubscribedReaders() async {
        let viewModel = TodayViewModel(service: ManyStoriesMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()
        let stories = viewModel.briefing?.allStories ?? []
        for story in stories.prefix(9) {
            viewModel.markRead(story.id)
        }

        XCTAssertFalse(viewModel.shouldPromptForSubscription(hasAccess: false))

        viewModel.markRead(stories[9].id)

        XCTAssertEqual(ReadingAccessPolicy.freeArticleLimit, 10)
        XCTAssertTrue(viewModel.shouldPromptForSubscription(hasAccess: false))
        XCTAssertFalse(viewModel.shouldPromptForSubscription(hasAccess: true))
    }

    func testDoneStoriesShowsReadStoriesInBriefingOrder() async {
        let viewModel = TodayViewModel(service: RankedMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()
        viewModel.markRead("economy")
        viewModel.markRead("middle-east")

        XCTAssertEqual(viewModel.doneStories.map(\.id), ["middle-east", "economy"])
        XCTAssertEqual(viewModel.storyQueue.map(\.id), ["health"])
    }

    func testExpiredStoriesLeaveQueueUnlessSaved() async {
        let viewModel = TodayViewModel(service: ExpiringMockService(), cache: NoopBriefingCache())
        let now = ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z")!

        await viewModel.loadToday()

        XCTAssertEqual(viewModel.storyQueue(savedStoryIDs: [], now: now).map(\.id), ["fresh"])
        XCTAssertEqual(viewModel.storyQueue(savedStoryIDs: ["expired"], now: now).map(\.id), ["expired", "fresh"])
    }

    func testStoryQueueUsesBackendRankBeforeSectionOrder() async {
        let viewModel = TodayViewModel(service: RankedMockService(), cache: NoopBriefingCache())

        await viewModel.loadToday()

        XCTAssertEqual(viewModel.storyQueue.map(\.id), ["middle-east", "health", "economy"])
    }

    func testStoryDetailDoesNotShowDefaultWarDetailBeforeArticleLoads() async {
        let viewModel = TodayViewModel(service: MockBriefingService(), cache: NoopBriefingCache())

        await viewModel.loadToday()

        XCTAssertNil(viewModel.storyDetail(id: "story_004"))
    }

    func testMockArticleDetailsUseMatchingStorySubject() async {
        let viewModel = TodayViewModel(service: MockBriefingService(), cache: NoopBriefingCache())

        await viewModel.loadToday()
        await viewModel.loadStory(id: "story_004")

        let detail = viewModel.storyDetail(id: "story_004")
        XCTAssertEqual(detail?.headline, "Aid groups report delays at crossing points")
        XCTAssertTrue(detail?.whatHappened.localizedCaseInsensitiveContains("convoys faced delays") == true)
        XCTAssertFalse(detail?.whatHappened.localizedCaseInsensitiveContains("Airstrikes were reported near the border") == true)
    }
}

struct ExpiringMockService: BriefingServing {
    func todayBriefing() async throws -> Briefing {
        Briefing(
            date: "2026-05-22",
            title: "Expiring Briefing",
            readingTimeMinutes: 3,
            emotionalLoad: .low,
            storyCount: 2,
            sections: [
                BriefingSection(
                    id: "world",
                    title: "World",
                    stories: [
                        StorySummary(
                            id: "expired",
                            rank: 1,
                            publishedAt: ISO8601DateFormatter().date(from: "2026-05-18T12:00:00Z"),
                            expiresAt: ISO8601DateFormatter().date(from: "2026-05-21T12:00:00Z"),
                            headline: "Expired story",
                            region: "World",
                            category: "World",
                            summary: "Old summary.",
                            whyItMatters: "Old context.",
                            confidence: .medium,
                            emotionalLoad: .low,
                            sourceCount: 2,
                            imageId: nil
                        ),
                        StorySummary(
                            id: "fresh",
                            rank: 2,
                            publishedAt: ISO8601DateFormatter().date(from: "2026-05-22T09:00:00Z"),
                            expiresAt: ISO8601DateFormatter().date(from: "2026-05-25T09:00:00Z"),
                            headline: "Fresh story",
                            region: "World",
                            category: "World",
                            summary: "Fresh summary.",
                            whyItMatters: "Fresh context.",
                            confidence: .medium,
                            emotionalLoad: .low,
                            sourceCount: 2,
                            imageId: nil
                        )
                    ]
                )
            ]
        )
    }

    func briefing(date: String) async throws -> Briefing { try await todayBriefing() }
    func todayUpdates() async throws -> BriefingUpdates {
        BriefingUpdates(date: "2026-05-22", generatedAt: Date(), status: "no-major-updates", summary: "No updates.", updates: [])
    }
    func article(id: String) async throws -> StoryDetail { MockData.defaultStory }
    func source(id: String) async throws -> Source { MockData.sources[0] }
    func savePreferences(_ preferences: UserPreferences) async throws {}
    func preferences() async throws -> UserPreferences { .defaults }
    func useDepthToken() async throws -> DepthTokenStatus { MockData.depthTokenStatus }
    func depthTokensToday() async throws -> DepthTokenStatus { MockData.depthTokenStatus }
}

struct ManyStoriesMockService: BriefingServing {
    func todayBriefing() async throws -> Briefing {
        let storyNumbers: [Int] = Array(1...12)
        return Briefing(
            date: "2026-05-18",
            title: "Many Stories",
            readingTimeMinutes: 8,
            emotionalLoad: .medium,
            storyCount: 12,
            sections: [
                BriefingSection(
                    id: "world",
                    title: "World",
                    stories: storyNumbers.map { storyIndex in
                        StorySummary(
                            id: "story_\(storyIndex)",
                            rank: storyIndex,
                            headline: "Story \(storyIndex)",
                            region: "World",
                            category: "World",
                            summary: "Summary \(storyIndex).",
                            whyItMatters: "Context \(storyIndex).",
                            confidence: .medium,
                            emotionalLoad: .low,
                            sourceCount: 2,
                            imageId: nil
                        )
                    }
                )
            ]
        )
    }

    func briefing(date: String) async throws -> Briefing { try await todayBriefing() }
    func todayUpdates() async throws -> BriefingUpdates {
        BriefingUpdates(date: "2026-05-18", generatedAt: Date(), status: "no-major-updates", summary: "No updates.", updates: [])
    }
    func article(id: String) async throws -> StoryDetail { MockData.defaultStory }
    func source(id: String) async throws -> Source { MockData.sources[0] }
    func savePreferences(_ preferences: UserPreferences) async throws {}
    func preferences() async throws -> UserPreferences { .defaults }
    func useDepthToken() async throws -> DepthTokenStatus { MockData.depthTokenStatus }
    func depthTokensToday() async throws -> DepthTokenStatus { MockData.depthTokenStatus }
}

struct NoopBriefingCache: BriefingCaching {
    func save(_ briefing: Briefing) async throws {}
    func loadLastBriefing() async throws -> Briefing? { nil }
}

struct GraphicMockService: BriefingServing {
    func todayBriefing() async throws -> Briefing {
        Briefing(
            date: "2026-05-17",
            title: "Test Briefing",
            readingTimeMinutes: 4,
            emotionalLoad: .heavy,
            storyCount: 2,
            sections: [
                BriefingSection(
                    id: "test",
                    title: "Test",
                    stories: [
                        StorySummary(
                            id: "low",
                            headline: "Progress story",
                            region: "World",
                            category: "Progress",
                            summary: "A public health pilot improved access.",
                            whyItMatters: "The model may help other regions.",
                            confidence: .high,
                            emotionalLoad: .low,
                            sourceCount: 3,
                            imageId: nil
                        ),
                        StorySummary(
                            id: "graphic",
                            headline: "Graphic conflict story",
                            region: "World",
                            category: "Conflict",
                            summary: "A violent incident occurred.",
                            whyItMatters: "It may affect negotiations.",
                            confidence: .medium,
                            emotionalLoad: .graphic,
                            sourceCount: 3,
                            imageId: nil
                        )
                    ]
                )
            ]
        )
    }

    func briefing(date: String) async throws -> Briefing {
        try await todayBriefing()
    }

    func todayUpdates() async throws -> BriefingUpdates {
        BriefingUpdates(
            date: "2026-05-17",
            generatedAt: Date(timeIntervalSince1970: 1_779_000_000),
            status: "meaningful-updates",
            summary: "One meaningful update. No urgent attention required.",
            updates: [
                BriefingUpdate(
                    id: "update_test",
                    storyId: "graphic",
                    headline: "Graphic conflict story gained another source",
                    region: "World",
                    category: "Progress",
                    whatChanged: "A primary source added supporting data.",
                    whyItMatters: "The confidence rating is more stable.",
                    confidence: .high,
                    emotionalLoad: .low,
                    sourceCount: 4,
                    sourceTypes: ["primary"],
                    sourceMix: SourceMix(
                        wire: 0,
                        localRegional: 0,
                        official: 0,
                        ngo: 0,
                        primary: 1,
                        commentary: 0,
                        other: 0,
                        labels: ["primary"]
                    ),
                    isCritical: false
                )
            ]
        )
    }

    func article(id: String) async throws -> StoryDetail {
        MockData.defaultStory
    }

    func source(id: String) async throws -> Source {
        MockData.sources[0]
    }

    func savePreferences(_ preferences: UserPreferences) async throws {}

    func preferences() async throws -> UserPreferences {
        .defaults
    }

    func useDepthToken() async throws -> DepthTokenStatus {
        MockData.depthTokenStatus
    }

    func depthTokensToday() async throws -> DepthTokenStatus {
        MockData.depthTokenStatus
    }
}

struct RankedMockService: BriefingServing {
    func todayBriefing() async throws -> Briefing {
        Briefing(
            date: "2026-05-18",
            title: "Ranked Briefing",
            readingTimeMinutes: 4,
            emotionalLoad: .medium,
            storyCount: 3,
            sections: [
                BriefingSection(
                    id: "health",
                    title: "Health",
                    stories: [
                        StorySummary(
                            id: "health",
                            rank: 2,
                            headline: "Health story",
                            region: "Africa",
                            category: "Health",
                            summary: "Health summary.",
                            whyItMatters: "Health context.",
                            confidence: .medium,
                            emotionalLoad: .medium,
                            sourceCount: 2,
                            imageId: nil
                        )
                    ]
                ),
                BriefingSection(
                    id: "middle-east",
                    title: "Middle East",
                    stories: [
                        StorySummary(
                            id: "middle-east",
                            rank: 1,
                            headline: "Middle East story",
                            region: "Middle East",
                            category: "Conflict",
                            summary: "Conflict summary.",
                            whyItMatters: "Conflict context.",
                            confidence: .mediumHigh,
                            emotionalLoad: .heavy,
                            sourceCount: 4,
                            imageId: nil
                        )
                    ]
                ),
                BriefingSection(
                    id: "economy",
                    title: "Economy",
                    stories: [
                        StorySummary(
                            id: "economy",
                            rank: 3,
                            headline: "Economy story",
                            region: "World",
                            category: "Economy",
                            summary: "Economy summary.",
                            whyItMatters: "Economy context.",
                            confidence: .medium,
                            emotionalLoad: .medium,
                            sourceCount: 2,
                            imageId: nil
                        )
                    ]
                )
            ]
        )
    }

    func briefing(date: String) async throws -> Briefing {
        try await todayBriefing()
    }

    func todayUpdates() async throws -> BriefingUpdates {
        BriefingUpdates(date: "2026-05-18", generatedAt: Date(), status: "no-major-updates", summary: "No updates.", updates: [])
    }

    func article(id: String) async throws -> StoryDetail {
        MockData.defaultStory
    }

    func source(id: String) async throws -> Source {
        MockData.sources[0]
    }

    func savePreferences(_ preferences: UserPreferences) async throws {}

    func preferences() async throws -> UserPreferences {
        .defaults
    }

    func useDepthToken() async throws -> DepthTokenStatus {
        MockData.depthTokenStatus
    }

    func depthTokensToday() async throws -> DepthTokenStatus {
        MockData.depthTokenStatus
    }
}
