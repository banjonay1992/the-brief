import Foundation

struct MockBriefingService: BriefingServing {
    func todayBriefing() async throws -> Briefing {
        MockData.briefing
    }

    func briefing(date: String) async throws -> Briefing {
        MockData.briefing
    }

    func todayUpdates() async throws -> BriefingUpdates {
        MockData.updates
    }

    func article(id: String) async throws -> StoryDetail {
        MockData.storyDetails[id] ?? MockData.defaultStory
    }

    func source(id: String) async throws -> Source {
        MockData.sources.first { $0.id == id } ?? MockData.sources[0]
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

enum MockData {
    static let briefing = Briefing(
        date: "2026-05-17",
        title: "Today’s Global Briefing",
        readingTimeMinutes: 9,
        emotionalLoad: .medium,
        storyCount: 18,
        sections: [
            BriefingSection(id: "world", title: "World", stories: [stories[0], stories[1]]),
            BriefingSection(id: "middle-east", title: "Middle East", stories: [stories[2], stories[3]]),
            BriefingSection(id: "science-tech", title: "Science & Tech", stories: [stories[4]]),
            BriefingSection(id: "progress", title: "Progress / Good News", stories: [stories[5]])
        ]
    )

    static let stories = [
        StorySummary(
            id: "story_001",
            headline: "Ceasefire talks resume after overnight strikes",
            region: "Middle East",
            category: "Conflict",
            summary: "Negotiators resumed talks after renewed strikes near the border.",
            whyItMatters: "The exchange could weaken the current ceasefire framework.",
            confidence: .mediumHigh,
            emotionalLoad: .heavy,
            sourceCount: 5,
            imageId: "image_001"
        ),
        StorySummary(
            id: "story_002",
            headline: "Flood response expands after regional storms",
            region: "Africa",
            category: "Climate",
            summary: "Emergency teams expanded shelter and water support after severe flooding.",
            whyItMatters: "The response will test local infrastructure and international aid coordination.",
            confidence: .high,
            emotionalLoad: .medium,
            sourceCount: 6,
            imageId: nil
        ),
        StorySummary(
            id: "story_003",
            headline: "Border exchange raises concern over ceasefire durability",
            region: "Middle East",
            category: "Conflict",
            summary: "Military activity was reported near a disputed border area.",
            whyItMatters: "Similar exchanges have previously disrupted talks and civilian movement.",
            confidence: .medium,
            emotionalLoad: .heavy,
            sourceCount: 4,
            imageId: nil
        ),
        StorySummary(
            id: "story_004",
            headline: "Aid groups report delays at crossing points",
            region: "Middle East",
            category: "Humanitarian",
            summary: "Aid groups said some convoys faced delays, while officials said inspections continued.",
            whyItMatters: "Delays can affect medical supplies, food access, and public trust.",
            confidence: .medium,
            emotionalLoad: .heavy,
            sourceCount: 5,
            imageId: nil
        ),
        StorySummary(
            id: "story_005",
            headline: "New battery material shows stronger cold-weather performance",
            region: "Asia",
            category: "Science & Tech",
            summary: "Researchers reported improved performance in early laboratory testing.",
            whyItMatters: "Better cold-weather batteries could improve grid storage and transport reliability.",
            confidence: .mediumHigh,
            emotionalLoad: .low,
            sourceCount: 3,
            imageId: nil
        ),
        StorySummary(
            id: "story_006",
            headline: "Malaria pilot reports fewer severe cases",
            region: "Africa",
            category: "Health",
            summary: "A regional pilot reported fewer severe cases after expanded prevention work.",
            whyItMatters: "The results may guide future public-health funding if they hold up in wider review.",
            confidence: .mediumHigh,
            emotionalLoad: .low,
            sourceCount: 4,
            imageId: nil
        )
    ]

    static let updates = BriefingUpdates(
        date: "2026-05-17",
        generatedAt: ISO8601DateFormatter().date(from: "2026-05-17T12:30:00Z")!,
        status: "meaningful-updates",
        summary: "Three meaningful updates have changed the shape of today’s briefing. None require urgent attention.",
        updates: [
            BriefingUpdate(
                id: "update_001",
                storyId: "story_001",
                headline: "Talks continued after revised statements",
                region: "Middle East",
                category: "Conflict",
                whatChanged: "Mediators said talks continued after revised statements from both sides. Independent confirmation of the strike targets remains limited.",
                whyItMatters: "Continuation of talks reduces the immediate risk of collapse, but disputed claims still matter for ceasefire trust.",
                confidence: .mediumHigh,
                emotionalLoad: .medium,
                sourceCount: 4,
                sourceTypes: ["wire", "local", "official"],
                sourceMix: SourceMix(
                    wire: 1,
                    localRegional: 1,
                    official: 1,
                    ngo: 0,
                    primary: 0,
                    commentary: 0,
                    other: 0,
                    labels: ["wire", "local/regional", "official"]
                ),
                isCritical: false
            ),
            BriefingUpdate(
                id: "update_002",
                storyId: "story_005",
                headline: "Battery team released underlying test notes",
                region: "Asia",
                category: "Science & Tech",
                whatChanged: "The research team published additional lab notes, making the cold-weather performance claim easier to evaluate.",
                whyItMatters: "More transparent methods improve confidence, though independent replication is still needed before broad claims are warranted.",
                confidence: .mediumHigh,
                emotionalLoad: .low,
                sourceCount: 3,
                sourceTypes: ["primary", "analysis"],
                sourceMix: SourceMix(
                    wire: 0,
                    localRegional: 0,
                    official: 0,
                    ngo: 0,
                    primary: 1,
                    commentary: 1,
                    other: 0,
                    labels: ["primary", "analysis"]
                ),
                isCritical: false
            )
        ]
    )

    static let sources = [
        Source(
            id: "source_001",
            name: "Reuters",
            type: "wire",
            region: "International",
            url: URL(string: "https://example.com/reuters")!,
            publishedAt: ISO8601DateFormatter().date(from: "2026-05-17T09:00:00Z")!,
            framing: "International wire framing"
        ),
        Source(
            id: "source_002",
            name: "Regional Public Broadcaster",
            type: "local",
            region: "Middle East",
            url: URL(string: "https://example.com/local")!,
            publishedAt: ISO8601DateFormatter().date(from: "2026-05-17T10:00:00Z")!,
            framing: "Local and affected-population framing"
        ),
        Source(
            id: "source_003",
            name: "Human Rights Monitor",
            type: "NGO",
            region: "International",
            url: URL(string: "https://example.com/ngo")!,
            publishedAt: ISO8601DateFormatter().date(from: "2026-05-17T11:00:00Z")!,
            framing: "Civilian harm and legal-risk framing"
        )
    ]

    static let defaultStory = StoryDetail(
        id: "story_001",
        headline: "Ceasefire talks resume after overnight strikes",
        category: "Conflict",
        region: "Middle East",
        whatHappened: "Airstrikes were reported near the border overnight. The government carrying out the strikes said it targeted armed infrastructure. Local officials reported civilian damage. Independent verification of the exact targets remains limited.",
        whyItMatters: "The exchange could weaken ceasefire negotiations and increase the risk of broader regional escalation.",
        whatWeKnow: [
            "Strike locations were reported by multiple outlets.",
            "Talks resumed later in the day.",
            "Both sides issued conflicting statements."
        ],
        whatIsUnclear: [
            "Casualty figures remain disputed.",
            "Responsibility claims have not been independently verified.",
            "The intended targets have not been confirmed by independent investigators."
        ],
        framingCheck: FramingCheck(
            westernMainstream: "Often frames the strikes through regional security concerns.",
            localRegional: "Often frames the strikes as a sovereignty or ceasefire violation.",
            officialGovernment: "The government carrying out the strikes described them as defensive.",
            affectedPopulation: "Residents and local officials focused on civilian harm and disruption.",
            independentEvidence: "Available evidence confirms strikes occurred, but does not fully verify the intended targets.",
            humanRightsNGO: "Rights groups focus on proportionality, civilian risk, and access for investigators.",
            opposingSide: "The targeted side described the strikes as a ceasefire breach."
        ),
        confidence: EvidenceConfidence(
            rating: .mediumHigh,
            reason: "The event is confirmed by multiple sources, but target details and casualty figures remain disputed."
        ),
        emotionalLoad: .heavy,
        sources: sources,
        biasAudit: BiasAuditResult(
            passed: true,
            notes: [
                "Claims are attributed.",
                "No government framing is presented as neutral fact.",
                "Affected-population perspective included.",
                "Uncertainty stated clearly."
            ]
        ),
        depthAnalysis: DepthAnalysis(
            timeline: [
                "Overnight reports described strikes near the border.",
                "Officials from both sides issued competing statements.",
                "Negotiators resumed talks later in the day."
            ],
            keyActors: ["Government forces", "Armed group", "Local officials", "Civilian residents", "Mediators"],
            backgroundContext: "The area has seen repeated ceasefire strain. Similar incidents are often described differently by official, regional, and affected-population sources.",
            sourceComparison: "Wire reports confirm the event occurred. Local sources add civilian-impact details. Official statements disagree on targets and responsibility.",
            possibleOutcomes: [
                "Talks continue with tighter monitoring.",
                "Further strikes weaken trust in the ceasefire.",
                "Independent investigators clarify casualty and target claims."
            ],
            evidenceConfidence: EvidenceConfidence(
                rating: .medium,
                reason: "Several sources confirm the incident, but key claims remain contested."
            ),
            furtherReading: sources
        ),
        evidenceCheck: EvidenceCheck(
            claim: "A foreign intelligence agency secretly directed the attack.",
            classification: .speculative,
            why: "No primary documents or independently verified evidence currently support this. The claim is circulating mostly through commentary accounts and has not been confirmed by reliable reporting."
        )
    )

    static let storyDetails: [String: StoryDetail] = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0.mockDetail(sources: sources)) })

    static var depthTokenStatus: DepthTokenStatus {
        DepthTokenStatus(
            allowedPerDay: 3,
            remaining: 2,
            resetAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        )
    }
}

private extension StorySummary {
    func mockDetail(sources: [Source]) -> StoryDetail {
        StoryDetail(
            id: id,
            headline: headline,
            category: category,
            region: region,
            whatHappened: "\(summary) \(whyItMatters) Details are kept attributed in this development mock so the popup can be checked without reusing another story’s article text.",
            whyItMatters: whyItMatters,
            whatWeKnow: [
                "\(sourceCountText.capitalized) are associated with this story.",
                "The reported development is specific to \(region).",
                "The category is \(category)."
            ],
            whatIsUnclear: [
                "Further source detail may change the confidence explanation.",
                "Specific figures and actor claims should remain attributed."
            ],
            framingCheck: FramingCheck(
                westernMainstream: "May foreground the wider policy or security impact of \(headline.lowercased()).",
                localRegional: "May foreground the practical effects for people and institutions in \(region).",
                officialGovernment: "Official statements should be treated as claims unless independently verified.",
                affectedPopulation: "Affected people may focus on disruption, access, safety, or daily-life consequences.",
                independentEvidence: "Independent evidence remains strongest when multiple source types describe the same core event.",
                humanRightsNGO: category == "Humanitarian" || emotionalLoad == .heavy ? "NGO framing may focus on civilian access, harm reduction, and accountability." : nil,
                opposingSide: "Opposing or affected-side claims should be held to the same evidence standard."
            ),
            confidence: EvidenceConfidence(
                rating: confidence,
                reason: "\(sourceCountText.capitalized) support the broad development, while specific claims still need attribution."
            ),
            emotionalLoad: emotionalLoad,
            sources: sources,
            biasAudit: BiasAuditResult(
                passed: true,
                notes: [
                    "The mock detail is generated from the matching story summary.",
                    "Claims remain attributed.",
                    "No unrelated default story text is reused."
                ]
            ),
            depthAnalysis: nil,
            evidenceCheck: EvidenceCheck(
                claim: headline,
                classification: .plausibleUnconfirmed,
                why: "\(sourceCountText.capitalized) support the broad story, but detailed claims should still be checked against the listed sources."
            )
        )
    }
}
