import SwiftUI

struct BiasFramingExplanationView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    let storyID: String?

    init(storyID: String? = nil) {
        self.storyID = storyID
    }

    private var story: StoryDetail? {
        storyID.flatMap { todayViewModel.storyDetail(id: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Framing Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .calmScrollReveal()
                Text("No framing category is automatically correct. The app separates claims, confirmed evidence, and uncertainty using the same rules for every actor.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                    .signalCard()
                    .calmScrollReveal()
                if let story {
                    framingRows(story.framingCheck)
                    auditRows(story.biasAudit)
                } else {
                    generalRules
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .signalScreen()
        .navigationTitle("Framing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task {
            if let storyID {
                await todayViewModel.loadStory(id: storyID)
            }
        }
    }

    private func framingRows(_ framing: FramingCheck) -> some View {
        VStack(spacing: 12) {
            row("Western/mainstream framing", framing.westernMainstream)
            row("Local/regional framing", framing.localRegional)
            row("Government/official framing", framing.officialGovernment)
            row("Affected population framing", framing.affectedPopulation)
            row("Independent evidence framing", framing.independentEvidence)
            if let humanRightsNGO = framing.humanRightsNGO {
                row("Human rights / NGO framing", humanRightsNGO)
            }
            if let opposingSide = framing.opposingSide {
                row("Opposing-side framing", opposingSide)
            }
        }
    }

    private func auditRows(_ audit: BiasAuditResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bias audit")
                    .font(.headline)
                Spacer()
                MetadataPill(text: audit.passed ? "Passed" : "Needs rewrite", tint: audit.passed ? .signalSage : .signalClay)
            }
            ForEach(audit.notes, id: \.self) { note in
                Label(note, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
            }
        }
        .signalCard()
        .calmScrollReveal()
    }

    private var generalRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Claim attribution", "State who made each claim before treating it as established.")
            row("Equal evidence threshold", "Do not rate a claim higher because it comes from an ally or lower because it comes from an adversary.")
            row("Civilian distinction", "Do not flatten civilians into governments, militaries, parties, or armed groups.")
        }
    }

    private func row(_ title: String, _ body: String) -> some View {
        HStack(spacing: 12) {
            SignalIconTile(systemImage: icon(for: title), tint: tint(for: title))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(Color.signalMuted)
                    .lineLimit(3)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.signalMuted)
        }
        .signalCard()
        .calmScrollReveal()
    }

    private func icon(for title: String) -> String {
        if title.contains("Western") { return "globe" }
        if title.contains("Local") { return "mappin.and.ellipse" }
        if title.contains("Official") { return "building.columns" }
        if title.contains("Affected") { return "person.2" }
        if title.contains("Independent") { return "checkmark.shield" }
        if title.contains("Human") { return "person.crop.circle.badge.checkmark" }
        return "quote.bubble"
    }

    private func tint(for title: String) -> Color {
        if title.contains("Official") { return .signalOchre }
        if title.contains("Affected") || title.contains("Human") { return .signalSage }
        return .signalMuted
    }
}
