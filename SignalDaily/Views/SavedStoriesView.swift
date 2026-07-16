import SwiftUI

struct SavedStoriesView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    @Environment(SavedStoriesStore.self) private var savedStoriesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                CascadingText(
                    text: "Saved Stories",
                    font: .system(size: 34, weight: .semibold, design: .serif),
                    color: .signalInk
                )
                Text("Saved reading stays finite too. No social counters, no trending drawer, no public scoreboard.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                    .signalCard()
                    .calmScrollReveal()
                if savedStoriesStore.savedStoryIDs.isEmpty {
                    EmptySavedStoriesCard()
                } else {
                    ForEach(savedStoriesStore.savedStoryIDs, id: \.self) { storyID in
                        if let story = todayViewModel.storySummary(id: storyID)
                            ?? savedStoriesStore.snapshot(id: storyID)?.story
                            ?? MockData.stories.first(where: { $0.id == storyID }) {
                            StoryCardView(story: story)
                                .calmScrollReveal()
                        }
                    }
                }
            }
            .padding(20)
            .padding(.top, savedStoriesStore.savedStoryIDs.isEmpty ? SavedStoriesLayout.emptyStateTopPadding : 0)
        }
        .signalScreen()
        .navigationTitle("Saved")
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await todayViewModel.loadToday() }
    }
}

private struct EmptySavedStoriesCard: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Nothing saved yet")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Tap the bookmark on any story to keep it here. The briefing stays finite either way.")
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .signalCard()
        .calmScrollReveal()
    }
}

