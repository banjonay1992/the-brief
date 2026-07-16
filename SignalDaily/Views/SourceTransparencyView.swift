import SwiftUI

struct SourceTransparencyView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    let storyID: String

    private var story: StoryDetail? {
        todayViewModel.storyDetail(id: storyID)
    }

    var body: some View {
        Group {
            if let story {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sources")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .calmScrollReveal()
                        Text(story.headline)
                            .font(.headline)
                            .foregroundStyle(Color.signalMuted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .calmScrollReveal()
                        ForEach(story.sources) { source in
                            sourceCard(source)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .signalScreen()
            } else {
                EmptyStateView(
                    title: "Sources unavailable",
                    message: "Source metadata could not be loaded for this story.",
                    systemImage: "link"
                )
            }
        }
        .navigationTitle("Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await todayViewModel.loadStory(id: storyID) }
    }

    private func sourceCard(_ source: Source) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(source.name)
                    .font(.headline)
                Spacer()
                MetadataPill(text: source.type)
            }
            Text(source.region)
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
            Text(source.publishedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(Color.signalMuted)
            if let framing = source.framing {
                Text(framing)
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
            }
            Divider()
            Text("Confidence contribution: \(source.confidenceContributionText)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalSage)
            Link(destination: source.url) {
                Label("Open source", systemImage: "safari")
            }
            .font(.subheadline.weight(.semibold))
        }
        .signalCard()
        .calmScrollReveal()
    }
}
