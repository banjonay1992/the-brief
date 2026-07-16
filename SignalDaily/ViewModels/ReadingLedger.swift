import Foundation
import Observation

struct ReadStoryRecord: Codable, Identifiable, Equatable {
    let id: String
    let readAt: Date
    let briefingDate: String
    let story: StorySummary
}

/// Quiet, local-only record of the reading ritual: which stories were finished,
/// which mornings were completed, and when each story first appeared.
/// Powers the library, the calm-mornings count, and "Day N" thread markers.
/// Nothing here leaves the device.
@MainActor
@Observable
final class ReadingLedger {
    private let userDefaults: UserDefaults
    private let recordsKey: String
    private let morningsKey: String
    private let firstSeenKey: String

    private(set) var readRecords: [ReadStoryRecord]
    private(set) var completedMornings: [String]
    private(set) var firstSeenDates: [String: String]

    init(userDefaults: UserDefaults = .standard, storageKey: String = "readingLedger") {
        self.userDefaults = userDefaults
        self.recordsKey = "\(storageKey).records"
        self.morningsKey = "\(storageKey).mornings"
        self.firstSeenKey = "\(storageKey).firstSeen"
        self.readRecords = Self.decode([ReadStoryRecord].self, defaults: userDefaults, key: recordsKey) ?? []
        self.completedMornings = userDefaults.stringArray(forKey: morningsKey) ?? []
        self.firstSeenDates = Self.decode([String: String].self, defaults: userDefaults, key: firstSeenKey) ?? [:]
    }

    // MARK: - Library

    func recordRead(_ story: StorySummary, briefingDate: String, readAt: Date = .now) {
        guard !readRecords.contains(where: { $0.id == story.id && $0.briefingDate == briefingDate }) else { return }
        readRecords.append(ReadStoryRecord(id: story.id, readAt: readAt, briefingDate: briefingDate, story: story))
        persistRecords()
    }

    func readStoryIDs(briefingDate: String) -> Set<String> {
        Set(readRecords.filter { $0.briefingDate == briefingDate }.map(\.id))
    }

    var totalReadCount: Int {
        readRecords.count
    }

    var readingDayCount: Int {
        Set(readRecords.map(\.briefingDate)).count
    }

    /// Newest day first; records within a day keep read order.
    var recordsByDay: [(date: String, records: [ReadStoryRecord])] {
        let grouped = Dictionary(grouping: readRecords, by: \.briefingDate)
        return grouped.keys.sorted(by: >).map { date in
            (date: date, records: grouped[date] ?? [])
        }
    }

    // MARK: - Calm mornings

    func recordCompletedMorning(briefingDate: String) {
        guard !completedMornings.contains(briefingDate) else { return }
        completedMornings.append(briefingDate)
        userDefaults.set(completedMornings, forKey: morningsKey)
    }

    var calmMorningCount: Int {
        completedMornings.count
    }

    // MARK: - Story threads

    func noteSeen(stories: [StorySummary], briefingDate: String) {
        var changed = false
        for story in stories where firstSeenDates[story.id] == nil {
            firstSeenDates[story.id] = briefingDate
            changed = true
        }
        if changed {
            persistFirstSeen()
        }
    }

    /// 1 on the day a story first appeared, 2 the next day, and so on.
    /// Returns nil when the story has not been seen before.
    func threadDayNumber(storyID: String, briefingDate: String) -> Int? {
        guard let firstSeen = firstSeenDates[storyID],
              let start = Self.dayFormatter.date(from: firstSeen),
              let current = Self.dayFormatter.date(from: briefingDate),
              let days = Self.calendar.dateComponents([.day], from: start, to: current).day,
              days >= 0
        else {
            return nil
        }
        return days + 1
    }

    // MARK: - Persistence

    private func persistRecords() {
        if let data = try? SignalJSON.encoder.encode(readRecords) {
            userDefaults.set(data, forKey: recordsKey)
        }
    }

    private func persistFirstSeen() {
        if let data = try? SignalJSON.encoder.encode(firstSeenDates) {
            userDefaults.set(data, forKey: firstSeenKey)
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? SignalJSON.decoder.decode(T.self, from: data)
    }

    private static let calendar = Calendar(identifier: .gregorian)

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
