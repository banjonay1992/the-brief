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
            Text("Save a story from its detail page when you want to come back later. The app will still keep the briefing finite.")
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .signalCard()
        .calmScrollReveal()
    }
}

struct DoneStoriesView: View {
    @Environment(TodayViewModel.self) private var todayViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 14) {
                CascadingText(
                    text: "Done Stories",
                    font: .system(size: 34, weight: .semibold, design: .serif),
                    color: .signalInk
                )

                Text("A quiet record of cards you cleared today.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)

                if todayViewModel.doneStories.isEmpty {
                    EmptyDoneStoriesCard()
                        .padding(.top, 18)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(todayViewModel.doneStories) { story in
                            DoneStoryRow(story: story)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(20)
            .padding(.top, todayViewModel.doneStories.isEmpty ? SavedStoriesLayout.emptyStateTopPadding : 34)
        }
        .signalScreen()
        .navigationTitle("Done")
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await todayViewModel.loadToday() }
    }
}

private struct EmptyDoneStoriesCard: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Nothing marked done yet")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Cards you clear from Today will appear here in compact form.")
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .signalCard()
        .calmScrollReveal()
    }
}

private struct DoneStoryRow: View {
    let story: StorySummary

    var body: some View {
        NavigationLink(value: AppRoute.story(story.id)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.signalSage)
                    .frame(width: 26, height: 26)
                    .background(Color.signalSage.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(story.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.signalInk)
                        .lineLimit(2)

                    Text("\(story.region) · \(story.category)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.signalSage)

                    HStack(spacing: 8) {
                        Text(story.confidence.rawValue)
                        Text(story.sourceCountText)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.signalMuted)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.signalMuted.opacity(0.45))
                    .padding(.top, 5)
            }
            .padding(14)
            .background(Color.signalSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.signalLine.opacity(0.74), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .calmScrollReveal()
    }
}
