import XCTest
@testable import SignalDaily

final class NewsModelTests: XCTestCase {
    func testBriefingJSONDecodesBackendContract() throws {
        let json = """
        {
          "date": "2026-05-17",
          "title": "Today’s Global Briefing",
          "readingTimeMinutes": 9,
          "emotionalLoad": "Medium",
          "storyCount": 18,
          "sections": [
            {
              "id": "middle-east",
              "title": "Middle East",
              "stories": [
                {
                  "id": "story_001",
                  "rank": 1,
                  "publishedAt": "2026-05-18T12:00:00Z",
                  "expiresAt": "2026-05-21T12:00:00Z",
                  "headline": "Ceasefire talks resume after overnight strikes",
                  "region": "Middle East",
                  "category": "Conflict",
                  "summary": "Negotiators resumed talks after renewed strikes near the border.",
                  "whyItMatters": "The exchange could weaken the current ceasefire framework.",
                  "confidence": "Medium-high",
                  "emotionalLoad": "Heavy",
                  "sourceCount": 5,
                  "imageId": "image_001"
                }
              ]
            }
          ]
        }
        """

        let briefing = try SignalJSON.decoder.decode(Briefing.self, from: Data(json.utf8))

        XCTAssertEqual(briefing.date, "2026-05-17")
        XCTAssertEqual(briefing.sections.first?.stories.first?.confidence, .mediumHigh)
        XCTAssertEqual(briefing.sections.first?.stories.first?.rank, 1)
        XCTAssertEqual(briefing.sections.first?.stories.first?.publishedAt, ISO8601DateFormatter().date(from: "2026-05-18T12:00:00Z"))
        XCTAssertEqual(briefing.allStories.count, 1)
        XCTAssertEqual(briefing.sections.first?.stories.first?.sourceCountText, "5 sources")
    }

    func testStorySourceCountTextUsesSingularAndPlural() throws {
        let json = """
        {
          "id": "story_001",
          "headline": "Ceasefire talks resume after overnight strikes",
          "region": "Middle East",
          "category": "Conflict",
          "summary": "Negotiators resumed talks after renewed strikes near the border.",
          "whyItMatters": "The exchange could weaken the current ceasefire framework.",
          "confidence": "Medium-high",
          "emotionalLoad": "Heavy",
          "sourceCount": 1,
          "imageId": null
        }
        """

        let story = try SignalJSON.decoder.decode(StorySummary.self, from: Data(json.utf8))

        XCTAssertEqual(story.sourceCountText, "1 source")
    }

    func testStoryVisibilityUsesBackendExpiryWhenPresent() throws {
        let story = StorySummary(
            id: "story_expiring",
            publishedAt: ISO8601DateFormatter().date(from: "2026-05-18T12:00:00Z"),
            expiresAt: ISO8601DateFormatter().date(from: "2026-05-21T12:00:00Z"),
            headline: "Expiring story",
            region: "World",
            category: "World",
            summary: "Summary.",
            whyItMatters: "Context.",
            confidence: .medium,
            emotionalLoad: .low,
            sourceCount: 2,
            imageId: nil
        )

        XCTAssertTrue(story.isVisibleInFeed(now: ISO8601DateFormatter().date(from: "2026-05-20T12:00:00Z")!))
        XCTAssertFalse(story.isVisibleInFeed(now: ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z")!))
    }

    func testStoryDetailSeparatesClaimsFromConfirmedFacts() {
        let story = MockData.defaultStory

        XCTAssertTrue(story.whatHappened.localizedCaseInsensitiveContains("said"))
        XCTAssertTrue(story.whatHappened.localizedCaseInsensitiveContains("Independent verification"))
        XCTAssertTrue(story.whatIsUnclear.contains { $0.localizedCaseInsensitiveContains("disputed") })
        XCTAssertTrue(story.biasAudit.passed)
    }

    func testStoryDetailDecodesCountryAndVerificationContext() throws {
        let json = """
        {
          "id": "story_001",
          "headline": "Kenya flood shelters expand after heavy rains",
          "category": "Climate",
          "region": "Africa",
          "countries": ["Kenya"],
          "sourceCountries": ["Kenya", "Pan-African"],
          "verification": {
            "status": "Medium",
            "summary": "Two distinct sources are reporting related developments.",
            "checks": [
              "2 distinct sources matched in the live pipeline.",
              "At least one local or regional source is present."
            ]
          },
          "whatHappened": "Two sources reported related developments.",
          "whyItMatters": "Climate stories can affect infrastructure and displacement.",
          "whatWeKnow": ["The live pipeline matched 2 related reports."],
          "whatIsUnclear": ["More local sources may change confidence."],
          "framingCheck": {
            "westernMainstream": "International framing.",
            "localRegional": "Local framing.",
            "officialGovernment": "Official claims should be attributed.",
            "affectedPopulation": "Affected people may focus on disruption.",
            "independentEvidence": "Multiple publishers are reporting related developments.",
            "humanRightsNGO": null,
            "opposingSide": null
          },
          "confidence": {
            "rating": "Medium",
            "reason": "Two distinct sources are reporting related developments."
          },
          "emotionalLoad": "Medium",
          "sources": [],
          "biasAudit": {
            "passed": true,
            "notes": ["Uncertainty stated clearly."]
          },
          "depthAnalysis": null,
          "evidenceCheck": {
            "claim": "Kenya flood shelters expand after heavy rains",
            "classification": "Plausible but unconfirmed",
            "why": "The subject appears across multiple detected sources."
          }
        }
        """

        let story = try SignalJSON.decoder.decode(StoryDetail.self, from: Data(json.utf8))

        XCTAssertEqual(story.countries, ["Kenya"])
        XCTAssertEqual(story.sourceCountries, ["Kenya", "Pan-African"])
        XCTAssertEqual(story.verification?.status, .medium)
        XCTAssertEqual(story.verification?.checks.count, 2)
    }

    func testSourceDecodesQualityMetadata() throws {
        let json = """
        {
          "id": "source_reuters_com",
          "name": "Reuters",
          "type": "wire",
          "region": "International",
          "url": "https://reuters.com",
          "publishedAt": "2026-05-18T12:00:00Z",
          "framing": "International wire framing.",
          "qualityScore": 90,
          "qualityLabel": "High contribution"
        }
        """

        let source = try SignalJSON.decoder.decode(Source.self, from: Data(json.utf8))

        XCTAssertEqual(source.qualityScore, 90)
        XCTAssertEqual(source.confidenceContributionText, "High contribution")
    }

    func testLoadedTermsStayAttributedOrOutsideNeutralSummary() {
        let neutralSummary = MockData.defaultStory.whatHappened.lowercased()
        let forbiddenNeutralTerms = [
            "terrorist",
            "freedom fighter",
            "martyr",
            "surgical strike",
            "human shield",
            "collateral damage",
            "precision strike",
            "terror nest"
        ]

        for term in forbiddenNeutralTerms {
            XCTAssertFalse(neutralSummary.contains(term), "Neutral summary should not use \(term) as fact.")
        }

        XCTAssertTrue(MockData.defaultStory.framingCheck.officialGovernment.localizedCaseInsensitiveContains("described"))
    }

    func testDepthTokenUseStopsAtZero() {
        var status = DepthTokenStatus(
            allowedPerDay: 3,
            remaining: 1,
            resetAt: Date(timeIntervalSince1970: 1_780_000_000)
        )

        XCTAssertTrue(status.useToken())
        XCTAssertEqual(status.remaining, 0)
        XCTAssertFalse(status.useToken())
        XCTAssertEqual(status.displayText, "Depth tokens left today: 0/3")
    }

    func testBriefingUpdatesJSONDecodesFiniteLiveContract() throws {
        let json = """
        {
          "date": "2026-05-17",
          "generatedAt": "2026-05-17T12:30:00Z",
          "status": "meaningful-updates",
          "summary": "Three meaningful updates have changed the shape of today’s briefing.",
          "updates": [
            {
              "id": "update_001",
              "storyId": "story_001",
              "headline": "Talks continued after revised statements",
              "region": "Middle East",
              "category": "Conflict",
              "whatChanged": "Mediators said talks continued.",
              "whyItMatters": "It affects ceasefire confidence.",
              "confidence": "Medium-high",
              "emotionalLoad": "Medium",
              "sourceCount": 4,
              "sourceTypes": ["wire", "local"],
              "sourceMix": {
                "wire": 1,
                "localRegional": 1,
                "official": 0,
                "ngo": 0,
                "primary": 0,
                "commentary": 0,
                "other": 0,
                "labels": ["wire", "local/regional"]
              },
              "isCritical": false
            }
          ]
        }
        """

        let updates = try SignalJSON.decoder.decode(BriefingUpdates.self, from: Data(json.utf8))

        XCTAssertTrue(updates.hasMeaningfulUpdates)
        XCTAssertEqual(updates.updates.first?.confidence, .mediumHigh)
        XCTAssertEqual(updates.updates.first?.sourceTypes, ["wire", "local"])
        XCTAssertEqual(updates.updates.first?.sourceMix?.displayText, "wire + local")
    }
}
