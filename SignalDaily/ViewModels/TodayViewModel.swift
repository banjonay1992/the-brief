import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case offlineCached
        case failed(String)
    }

    private let service: BriefingServing
    private let cache: BriefingCaching
    private(set) var briefing: Briefing?
    private(set) var updates: BriefingUpdates?
    private(set) var storyDetails: [String: StoryDetail] = [:]
    private(set) var depthTokenStatus: DepthTokenStatus = MockData.depthTokenStatus
    private(set) var readStoryIDs: Set<String> = []
    var loadingState: LoadingState = .idle
    var selectedMode: BriefingMode = .balanced

    /// The day's deck is finite even when the feed upstream is not.
    /// Mirrors the user's "max stories" preference.
    var maxStories: Int = UserPreferences.defaults.maxStories

    init(service: BriefingServing = MockBriefingService(), cache: BriefingCaching = FileBriefingCache()) {
        self.service = service
        self.cache = cache
    }

    func loadToday() async {
        guard loadingState != .loading else { return }
        loadingState = .loading
        do {
            let briefing = try await service.todayBriefing()
            self.briefing = filteredBriefing(briefing)
            try await cache.save(briefing)
            depthTokenStatus = try await service.depthTokensToday()
            updates = try? await service.todayUpdates()
            loadingState = .loaded
        } catch {
            await loadCachedBriefing(fallbackError: error)
        }
    }

    func section(id: String) -> BriefingSection? {
        briefing?.sections.first { $0.id == id }
    }

    func storySummary(id: String) -> StorySummary? {
        briefing?.allStories.first { $0.id == id }
    }

    func storyDetail(id: String) -> StoryDetail? {
        storyDetails[id]
    }

    func evidenceCheck(id: String) -> EvidenceCheck? {
        storyDetail(id: id)?.evidenceCheck
    }

    /// Today's finite deck: the top-ranked stories up to the user's cap.
    var dayStories: [StorySummary] {
        guard let briefing else { return [] }
        return Array(briefing.allStories.sortedByBriefingRank().prefix(max(maxStories, 1)))
    }

    var readProgressText: String {
        guard briefing != nil else { return "No stories read yet" }
        return "\(readableStoryCount)/\(dayStories.count) read"
    }

    var readableStoryCount: Int {
        readStoryIDs.intersection(Set(dayStories.map(\.id))).count
    }

    func shouldPromptForSubscription(hasAccess: Bool) -> Bool {
        !hasAccess && readableStoryCount >= ReadingAccessPolicy.freeArticleLimit
    }

    var storyQueue: [StorySummary] {
        storyQueue(savedStoryIDs: [])
    }

    func storyQueue(savedStoryIDs: Set<String>, now: Date = .now) -> [StorySummary] {
        guard briefing != nil else { return [] }
        let stories = dayStories
        let byID = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
        let updatedIDs = updates?.updates.compactMap(\.storyId) ?? []
        var seen = Set<String>()
        let updatedStories = updatedIDs.compactMap { id -> StorySummary? in
            guard !seen.contains(id), !readStoryIDs.contains(id), let story = byID[id], story.isVisibleInFeed(now: now) || savedStoryIDs.contains(id) else { return nil }
            seen.insert(id)
            return story
        }
        return updatedStories + stories.filter {
            !seen.contains($0.id)
            && !readStoryIDs.contains($0.id)
            && ($0.isVisibleInFeed(now: now) || savedStoryIDs.contains($0.id))
        }
    }

    var doneStories: [StorySummary] {
        dayStories.filter { readStoryIDs.contains($0.id) }
    }

    func loadStory(id: String) async {
        if storyDetails[id] != nil { return }
        do {
            storyDetails[id] = try await service.article(id: id)
        } catch {
            return
        }
    }

    func markRead(_ storyID: String) {
        readStoryIDs.insert(storyID)
    }

    func hydrateReadStories(_ ids: Set<String>) {
        readStoryIDs.formUnion(ids)
    }

    func useDepthToken() async {
        guard depthTokenStatus.canUseToken else { return }
        do {
            depthTokenStatus = try await service.useDepthToken()
        } catch {
            _ = depthTokenStatus.useToken()
        }
    }

    private func loadCachedBriefing(fallbackError: Error) async {
        do {
            if let cached = try await cache.loadLastBriefing() {
                briefing = filteredBriefing(cached)
                loadingState = .offlineCached
                return
            }
            loadingState = .failed("Today’s briefing isn’t ready yet. Try again shortly, or read yesterday’s briefing.")
        } catch {
            loadingState = .failed(fallbackError.localizedDescription)
        }
    }

    private func filteredBriefing(_ briefing: Briefing) -> Briefing {
        switch selectedMode {
        case .full:
            briefing
        case .balanced:
            briefing
        case .lowIntensity:
            Briefing(
                date: briefing.date,
                title: briefing.title,
                readingTimeMinutes: briefing.readingTimeMinutes,
                emotionalLoad: .medium,
                storyCount: briefing.sections.flatMap { $0.stories }.filter { $0.emotionalLoad != .graphic }.count,
                sections: briefing.sections.map { section in
                    BriefingSection(id: section.id, title: section.title, stories: section.stories.filter { $0.emotionalLoad != .graphic })
                }
            )
        case .progressOnly:
            Briefing(
                date: briefing.date,
                title: "Progress Briefing",
                readingTimeMinutes: max(2, briefing.readingTimeMinutes / 3),
                emotionalLoad: .low,
                storyCount: briefing.sections.flatMap(\.stories).filter { $0.emotionalLoad == .low }.count,
                sections: briefing.sections.compactMap { section in
                    let stories = section.stories.filter { $0.emotionalLoad == .low }
                    return stories.isEmpty ? nil : BriefingSection(id: section.id, title: section.title, stories: stories)
                }
            )
        }
    }
}

enum ReadingAccessPolicy {
    static let freeArticleLimit = 10
}

private extension Array where Element == StorySummary {
    func sortedByBriefingRank() -> [StorySummary] {
        enumerated()
            .sorted { left, right in
                switch (left.element.rank, right.element.rank) {
                case let (leftRank?, rightRank?):
                    if leftRank != rightRank { return leftRank < rightRank }
                    return left.offset < right.offset
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return left.offset < right.offset
                }
            }
            .map(\.element)
    }
}
