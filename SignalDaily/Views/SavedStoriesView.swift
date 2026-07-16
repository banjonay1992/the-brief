import SwiftUI

struct SavedStoriesView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    @Environment(SavedStoriesStore.self) private var savedStoriesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 14) {
                CascadingText(
                    text: "Saved Stories",
                    font: .system(size: 34, weight: .semibold, design: .serif),
                    color: .signalInk
                )

                Text("Saved reading stays finite too. No social counters, no trending drawer, no public scoreboard.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                if savedStoriesStore.savedStoryIDs.isEmpty {
                    EmptySavedStoriesCard()
                        .padding(.top, 18)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(savedStoriesStore.savedStoryIDs, id: \.self) { storyID in
                            if let story = todayViewModel.storySummary(id: storyID)
                                ?? savedStoriesStore.snapshot(id: storyID)?.story
                                ?? MockData.stories.first(where: { $0.id == storyID }) {
                                SavedStoryCard(
                                    story: story,
                                    savedAt: savedStoriesStore.snapshot(id: storyID)?.savedAt,
                                    onToggleSave: {
                                        withAnimation(.easeInOut(duration: 0.24)) {
                                            savedStoriesStore.toggle(story)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(20)
            .padding(.top, savedStoriesStore.savedStoryIDs.isEmpty ? SavedStoriesLayout.emptyStateTopPadding : 24)
        }
        .calmWater(intensity: 0.55)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await todayViewModel.loadToday() }
    }
}

private struct SavedStoryCard: View {
    let story: StorySummary
    let savedAt: Date?
    let onToggleSave: () -> Void

    private var accent: Color {
        CategoryStyle.tint(for: story.category)
    }

    var body: some View {
        NavigationLink(value: AppRoute.story(story.id)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text(StoryKicker.text(region: story.region, category: story.category))
                        .font(.caption.weight(.semibold))
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    Image(systemName: "bookmark.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.signalPowderDeep)
                        .frame(width: 30, height: 30)
                        .background(Color.signalPowder.opacity(0.4), in: Circle())
                        .contentShape(Circle())
                        .onTapGesture(perform: onToggleSave)
                        .accessibilityLabel("Remove from saved")
                }

                Text(story.headline)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(Color.signalInk)
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)

                Text(story.summary)
                    .font(.subheadline)
                    .lineSpacing(2)
                    .foregroundStyle(Color.signalMuted)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    Text(story.confidence.rawValue)
                        .foregroundStyle(accent)
                    Text(story.sourceCountText)
                        .foregroundStyle(Color.signalMuted)
                    Spacer()
                    if let savedAt {
                        Text("Saved \(savedAt.formatted(.dateTime.day().month(.wide)))")
                            .foregroundStyle(Color.signalMuted.opacity(0.8))
                    }
                }
                .font(.caption.weight(.medium))
                .padding(.top, 2)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.signalSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .calmScrollReveal()
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
