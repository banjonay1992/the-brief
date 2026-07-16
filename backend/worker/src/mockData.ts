export const briefing = {
  date: "2026-05-17",
  title: "Today’s Global Briefing",
  readingTimeMinutes: 9,
  emotionalLoad: "Medium",
  storyCount: 18,
  sections: [
    {
      id: "middle-east",
      title: "Middle East",
      stories: [
        {
          id: "story_001",
          headline: "Ceasefire talks resume after overnight strikes",
          region: "Middle East",
          category: "Conflict",
          summary: "Negotiators resumed talks after renewed strikes near the border.",
          whyItMatters: "The exchange could weaken the current ceasefire framework.",
          confidence: "Medium-high",
          emotionalLoad: "Heavy",
          sourceCount: 5,
          imageId: "image_001"
        }
      ]
    },
    {
      id: "progress",
      title: "Progress / Good News",
      stories: [
        {
          id: "story_006",
          headline: "Malaria pilot reports fewer severe cases",
          region: "Africa",
          category: "Health",
          summary: "A regional pilot reported fewer severe cases after expanded prevention work.",
          whyItMatters: "The results may guide future public-health funding if they hold up in wider review.",
          confidence: "Medium-high",
          emotionalLoad: "Low",
          sourceCount: 4,
          imageId: null
        }
      ]
    }
  ]
} as const;

export const source = {
  id: "source_001",
  name: "Reuters",
  type: "wire",
  region: "International",
  url: "https://example.com/reuters",
  publishedAt: "2026-05-17T09:00:00Z",
  framing: "International wire framing"
} as const;

export const story = {
  id: "story_001",
  headline: "Ceasefire talks resume after overnight strikes",
  category: "Conflict",
  region: "Middle East",
  whatHappened:
    "Airstrikes were reported near the border overnight. The government carrying out the strikes said it targeted armed infrastructure. Local officials reported civilian damage. Independent verification of the exact targets remains limited.",
  whyItMatters:
    "The exchange could weaken ceasefire negotiations and increase the risk of broader regional escalation.",
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
  framingCheck: {
    westernMainstream: "Often frames the strikes through regional security concerns.",
    localRegional: "Often frames the strikes as a sovereignty or ceasefire violation.",
    officialGovernment: "The government carrying out the strikes described them as defensive.",
    affectedPopulation: "Residents and local officials focused on civilian harm and disruption.",
    independentEvidence:
      "Available evidence confirms strikes occurred, but does not fully verify the intended targets.",
    humanRightsNGO: "Rights groups focus on proportionality, civilian risk, and access for investigators.",
    opposingSide: "The targeted side described the strikes as a ceasefire breach."
  },
  confidence: {
    rating: "Medium-high",
    reason:
      "The event is confirmed by multiple sources, but target details and casualty figures remain disputed."
  },
  emotionalLoad: "Heavy",
  sources: [source],
  biasAudit: {
    passed: true,
    notes: [
      "Claims are attributed.",
      "No government framing is presented as neutral fact.",
      "Affected-population perspective included.",
      "Uncertainty stated clearly."
    ]
  },
  depthAnalysis: {
    timeline: [
      "Overnight reports described strikes near the border.",
      "Officials from both sides issued competing statements.",
      "Negotiators resumed talks later in the day."
    ],
    keyActors: ["Government forces", "Armed group", "Local officials", "Civilian residents", "Mediators"],
    backgroundContext:
      "The area has seen repeated ceasefire strain. Similar incidents are often described differently by official, regional, and affected-population sources.",
    sourceComparison:
      "Wire reports confirm the event occurred. Local sources add civilian-impact details. Official statements disagree on targets and responsibility.",
    possibleOutcomes: [
      "Talks continue with tighter monitoring.",
      "Further strikes weaken trust in the ceasefire.",
      "Independent investigators clarify casualty and target claims."
    ],
    evidenceConfidence: {
      rating: "Medium",
      reason: "Several sources confirm the incident, but key claims remain contested."
    },
    furtherReading: [source]
  },
  evidenceCheck: {
    claim: "A foreign intelligence agency secretly directed the attack.",
    classification: "Speculative",
    why:
      "No primary documents or independently verified evidence currently support this. The claim is circulating mostly through commentary accounts and has not been confirmed by reliable reporting."
  }
} as const;

export const userPreferences = {
  regions: ["World", "UK", "Middle East", "US"],
  topics: ["Conflict", "Science", "Technology", "Economy"],
  briefingMode: "Balanced Briefing",
  maxStories: 20,
  lowIntensityDefault: false,
  dailyReminderEnabled: true,
  dailyReminderTime: "08:00",
  showGraphicContent: false,
  includeProgressSection: true,
  showFramingChecks: true,
  showConfidenceReasons: true
} as const;

export const depthTokenStatus = {
  allowedPerDay: 3,
  remaining: 3,
  resetAt: "2026-05-18T00:00:00Z"
} as const;

export const calmUpdates = {
  date: "2026-05-17",
  generatedAt: "2026-05-17T12:30:00Z",
  status: "meaningful-updates",
  summary: "Three meaningful updates have changed the shape of today’s briefing. None require urgent attention.",
  updates: [
    {
      id: "update_001",
      storyId: "story_001",
      headline: "Talks continued after both sides issued revised statements",
      region: "Middle East",
      category: "Conflict",
      whatChanged:
        "Mediators said talks continued after revised statements from both sides. Independent confirmation of the strike targets remains limited.",
      whyItMatters:
        "Continuation of talks reduces the immediate risk of collapse, but the disputed claims still matter for ceasefire trust.",
      confidence: "Medium-high",
      emotionalLoad: "Medium",
      sourceCount: 4,
      sourceTypes: ["wire", "local", "official"],
      sourceMix: {
        wire: 1,
        localRegional: 1,
        official: 1,
        ngo: 0,
        primary: 0,
        commentary: 0,
        other: 0,
        labels: ["wire", "local/regional", "official"]
      },
      isCritical: false
    },
    {
      id: "update_002",
      storyId: "story_002",
      headline: "Flood shelters expanded as water levels began to recede",
      region: "Africa",
      category: "Climate",
      whatChanged:
        "Local officials and aid groups reported additional shelters opening while some monitoring points showed lower water levels.",
      whyItMatters:
        "The response is shifting from immediate evacuation toward shelter capacity, water safety, and disease prevention.",
      confidence: "High",
      emotionalLoad: "Medium",
      sourceCount: 5,
      sourceTypes: ["local", "NGO", "official"],
      sourceMix: {
        wire: 0,
        localRegional: 1,
        official: 1,
        ngo: 1,
        primary: 0,
        commentary: 0,
        other: 0,
        labels: ["local/regional", "official", "NGO"]
      },
      isCritical: false
    },
    {
      id: "update_003",
      storyId: "story_005",
      headline: "Battery researchers released the underlying test notes",
      region: "Asia",
      category: "Science & Tech",
      whatChanged:
        "The research team published additional lab notes, making the cold-weather performance claim easier to evaluate.",
      whyItMatters:
        "More transparent methods improve confidence, though independent replication is still needed before broad claims are warranted.",
      confidence: "Medium-high",
      emotionalLoad: "Low",
      sourceCount: 3,
      sourceTypes: ["primary", "analysis"],
      sourceMix: {
        wire: 0,
        localRegional: 0,
        official: 0,
        ngo: 0,
        primary: 1,
        commentary: 1,
        other: 0,
        labels: ["primary", "analysis"]
      },
      isCritical: false
    }
  ]
} as const;
