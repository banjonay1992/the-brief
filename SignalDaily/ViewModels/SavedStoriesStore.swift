import Foundation
import Observation

@MainActor
@Observable
final class SavedStoriesStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let snapshotsKey: String
    private(set) var savedStoryIDs: [String]
    private(set) var savedStorySnapshots: [SavedStorySnapshot]

    init(userDefaults: UserDefaults = .standard, storageKey: String = "savedStoryIDs") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.snapshotsKey = "\(storageKey).snapshots"
        self.savedStoryIDs = userDefaults.stringArray(forKey: storageKey) ?? []
        self.savedStorySnapshots = Self.loadSnapshots(defaults: userDefaults, key: snapshotsKey)
    }

    func contains(_ storyID: String) -> Bool {
        savedStoryIDs.contains(storyID)
    }

    func toggle(_ storyID: String) {
        if contains(storyID) {
            savedStoryIDs.removeAll { $0 == storyID }
            savedStorySnapshots.removeAll { $0.id == storyID }
        } else {
            savedStoryIDs.insert(storyID, at: 0)
        }
        persist()
    }

    func toggle(_ story: StorySummary, savedAt: Date = .now) {
        if contains(story.id) {
            savedStoryIDs.removeAll { $0 == story.id }
            savedStorySnapshots.removeAll { $0.id == story.id }
        } else {
            savedStoryIDs.insert(story.id, at: 0)
            savedStorySnapshots.insert(SavedStorySnapshot(id: story.id, savedAt: savedAt, story: story), at: 0)
        }
        persist()
    }

    func snapshot(id: String) -> SavedStorySnapshot? {
        savedStorySnapshots.first { $0.id == id }
    }

    private func persist() {
        userDefaults.set(savedStoryIDs, forKey: storageKey)
        if let data = try? SignalJSON.encoder.encode(savedStorySnapshots) {
            userDefaults.set(data, forKey: snapshotsKey)
        }
    }

    private static func loadSnapshots(defaults: UserDefaults, key: String) -> [SavedStorySnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? SignalJSON.decoder.decode([SavedStorySnapshot].self, from: data)) ?? []
    }
}
