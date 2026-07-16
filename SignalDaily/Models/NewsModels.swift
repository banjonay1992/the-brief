import Foundation

enum EmotionalLoad: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case heavy = "Heavy"
    case graphic = "Graphic / distressing"

    var id: String { rawValue }
}

enum ConfidenceRating: String, Codable, CaseIterable, Identifiable {
    case high = "High"
    case mediumHigh = "Medium-high"
    case medium = "Medium"
    case low = "Low"
    case unverified = "Unverified"
    case disputed = "Disputed"

    var id: String { rawValue }
}

enum BriefingMode: String, Codable, CaseIterable, Identifiable {
    case full = "Full Briefing"
    case balanced = "Balanced Briefing"
    case lowIntensity = "Low-Intensity Briefing"
    case progressOnly = "Progress-Only Briefing"

    var id: String { rawValue }
}

enum EvidenceClassification: String, Codable, CaseIterable, Identifiable {
    case confirmed = "Confirmed"
    case plausibleUnconfirmed = "Plausible but unconfirmed"
    case speculative = "Speculative"
    case narrativeTrap = "Narrative trap"
    case likelyFalse = "Likely false"

    var id: String { rawValue }
}

struct Briefing: Codable, Identifiable, Equatable {
    var id: String { date }
    let date: String
    let title: String
    let readingTimeMinutes: Int
    let emotionalLoad: EmotionalLoad
    let storyCount: Int
    let sections: [BriefingSection]

    var allStories: [StorySummary] {
        sections.flatMap(\.stories)
    }
}

struct BriefingSection: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let stories: [StorySummary]
}

struct StorySummary: Codable, Identifiable, Equatable {
    let id: String
    var rank: Int? = nil
    var publishedAt: Date? = nil
    var expiresAt: Date? = nil
    let headline: String
    let region: String
    let category: String
    let summary: String
    let whyItMatters: String
    let confidence: ConfidenceRating
    let emotionalLoad: EmotionalLoad
    let sourceCount: Int
    let imageId: String?

    var sourceCountText: String {
        sourceCount == 1 ? "1 source" : "\(sourceCount) sources"
    }

    func isVisibleInFeed(now: Date = .now) -> Bool {
        guard let expiresAt else { return true }
        return now < expiresAt
    }
}

struct SavedStorySnapshot: Codable, Identifiable, Equatable {
    let id: String
    let savedAt: Date
    let story: StorySummary
}

struct BriefingUpdates: Codable, Equatable {
    let date: String
    let generatedAt: Date
    let status: String
    let summary: String
    let updates: [BriefingUpdate]

    var hasMeaningfulUpdates: Bool {
        !updates.isEmpty
    }
}

struct BriefingUpdate: Codable, Identifiable, Equatable {
    let id: String
    let storyId: String?
    let headline: String
    let region: String
    let category: String
    let whatChanged: String
    let whyItMatters: String
    let confidence: ConfidenceRating
    let emotionalLoad: EmotionalLoad
    let sourceCount: Int
    let sourceTypes: [String]
    let sourceMix: SourceMix?
    let isCritical: Bool
}

struct SourceMix: Codable, Equatable {
    let wire: Int
    let localRegional: Int
    let official: Int
    let ngo: Int
    let primary: Int
    let commentary: Int
    let other: Int
    let labels: [String]

    var displayText: String {
        labels
            .map { $0 == "local/regional" ? "local" : $0 }
            .joined(separator: " + ")
    }
}

struct StoryDetail: Codable, Identifiable, Equatable {
    let id: String
    let headline: String
    let category: String
    let region: String
    var countries: [String]? = nil
    var sourceCountries: [String]? = nil
    var verification: StoryVerification? = nil
    let whatHappened: String
    let whyItMatters: String
    let whatWeKnow: [String]
    let whatIsUnclear: [String]
    let framingCheck: FramingCheck
    let confidence: EvidenceConfidence
    let emotionalLoad: EmotionalLoad
    let sources: [Source]
    let biasAudit: BiasAuditResult
    let depthAnalysis: DepthAnalysis?
    let evidenceCheck: EvidenceCheck?
}

struct StoryVerification: Codable, Equatable {
    let status: ConfidenceRating
    let summary: String
    let checks: [String]
}

struct EvidenceConfidence: Codable, Equatable {
    let rating: ConfidenceRating
    let reason: String
}

struct FramingCheck: Codable, Equatable {
    let westernMainstream: String
    let localRegional: String
    let officialGovernment: String
    let affectedPopulation: String
    let independentEvidence: String
    let humanRightsNGO: String?
    let opposingSide: String?
}

struct Source: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let type: String
    let region: String
    let url: URL
    let publishedAt: Date
    let framing: String?
    var qualityScore: Int? = nil
    var qualityLabel: String? = nil

    var confidenceContributionText: String {
        qualityLabel ?? "Context source"
    }
}

struct UserPreferences: Codable, Equatable {
    var regions: [String]
    var topics: [String]
    var briefingMode: BriefingMode
    var maxStories: Int
    var lowIntensityDefault: Bool
    var dailyReminderEnabled: Bool
    var dailyReminderTime: String
    var showGraphicContent: Bool
    var includeProgressSection: Bool
    var showFramingChecks: Bool
    var showConfidenceReasons: Bool

    static let defaults = UserPreferences(
        regions: ["World", "UK", "Middle East", "US"],
        topics: ["Conflict", "Science", "Technology", "Economy"],
        briefingMode: .balanced,
        maxStories: 20,
        lowIntensityDefault: false,
        dailyReminderEnabled: true,
        dailyReminderTime: "08:00",
        showGraphicContent: false,
        includeProgressSection: true,
        showFramingChecks: true,
        showConfidenceReasons: true
    )
}

struct DepthTokenStatus: Codable, Equatable {
    let allowedPerDay: Int
    var remaining: Int
    let resetAt: Date

    var displayText: String {
        "Depth tokens left today: \(remaining)/\(allowedPerDay)"
    }

    var canUseToken: Bool {
        remaining > 0
    }

    mutating func useToken() -> Bool {
        guard remaining > 0 else { return false }
        remaining -= 1
        return true
    }
}

struct EvidenceCheck: Codable, Equatable {
    let claim: String
    let classification: EvidenceClassification
    let why: String
}

struct BiasAuditResult: Codable, Equatable {
    let passed: Bool
    let notes: [String]
}

struct DepthAnalysis: Codable, Equatable {
    let timeline: [String]
    let keyActors: [String]
    let backgroundContext: String
    let sourceComparison: String
    let possibleOutcomes: [String]
    let evidenceConfidence: EvidenceConfidence
    let furtherReading: [Source]
}
