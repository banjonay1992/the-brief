import SwiftUI

struct DepthAnalysisView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    let storyID: String

    private var story: StoryDetail? {
        todayViewModel.storyDetail(id: storyID)
    }

    private var tokenStatus: DepthTokenStatus {
        todayViewModel.depthTokenStatus
    }

    var body: some View {
        Group {
            if let story, let depth = story.depthAnalysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Depth Analysis")
                                .font(.largeTitle.bold())
                            Spacer()
                        }
                        Text(tokenStatus.displayText)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.signalMuted)
                        if tokenStatus.canUseToken {
                            CalmButton(title: "Use one depth token", systemImage: "plus.circle") {
                                Task { await todayViewModel.useDepthToken() }
                            }
                        } else {
                            Text("You can still read summaries. Deeper analysis resets tomorrow.")
                                .font(.subheadline)
                                .foregroundStyle(Color.signalMuted)
                                .signalCard()
                        }
                        depthBlock("Timeline", depth.timeline)
                        plainBlock("Background context", depth.backgroundContext)
                        depthBlock("Key actors", depth.keyActors)
                        plainBlock("Source comparison", depth.sourceComparison)
                        depthBlock("Possible outcomes", depth.possibleOutcomes)
                        plainBlock("Evidence confidence", depth.evidenceConfidence.reason)
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .signalScreen()
            } else {
                EmptyStateView(
                    title: "Depth analysis unavailable",
                    message: "This story may only have the standard briefing summary for now.",
                    systemImage: "square.stack.3d.up.slash"
                )
            }
        }
        .navigationTitle("Depth")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await todayViewModel.loadStory(id: storyID) }
    }

    private func depthBlock(_ title: String, _ rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(rows, id: \.self) { row in
                Text(row)
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .signalCard()
    }

    private func plainBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
        }
        .signalCard()
    }
}
