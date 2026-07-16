import SwiftUI

struct StoryDetailView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    @Environment(SavedStoriesStore.self) private var savedStoriesStore
    let storyID: String

    private var story: StoryDetail? {
        todayViewModel.storyDetail(id: storyID)
    }

    var body: some View {
        Group {
            if let story {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        storyHeader(story)
                        evidencePanel(story)
                        actionGrid(story)
                        saveButton(story)
                    }
                    .padding(20)
                    .padding(.bottom, 24)
                }
                .signalScreen()
                .task {
                    todayViewModel.markRead(storyID)
                    await todayViewModel.loadStory(id: storyID)
                }
            } else {
                EmptyStateView(
                    title: "Article unavailable",
                    message: "This story could not be opened. Try again shortly.",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func storyHeader(_ story: StoryDetail) -> some View {
        VStack(alignment: .center, spacing: 10) {
            Text(story.region.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.signalSage)
                .multilineTextAlignment(.center)
            Text(story.headline)
                .font(.system(size: 31, weight: .regular, design: .serif))
                .foregroundStyle(Color.signalInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                SignalMetric(systemImage: "calendar", text: "17 May 2026")
                SignalMetric(systemImage: "clock", text: "5 min read")
                Spacer()
                MetadataPill(text: story.emotionalLoad.rawValue, tint: story.emotionalLoad == .heavy ? .signalClay : .signalSage)
            }
        }
        .frame(maxWidth: .infinity)
        .calmScrollReveal()
    }

    private func evidencePanel(_ story: StoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            panelSection("What happened", story.whatHappened)
            Divider()
            panelSection("Why it matters", story.whyItMatters)
            Divider()
            bulletSection("What we know", story.whatWeKnow, tint: .signalSage)
            Divider()
            bulletSection("What is unclear", story.whatIsUnclear, tint: .signalOchre)
            Divider()
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Evidence confidence")
                        .font(.headline)
                    Text(story.confidence.reason)
                        .font(.subheadline)
                        .foregroundStyle(Color.signalMuted)
                }
                Spacer()
                MetadataPill(text: story.confidence.rating.rawValue)
            }
        }
        .padding(16)
        .signalInsetPanel()
        .calmScrollReveal()
    }

    private func panelSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calmScrollReveal()
    }

    private func bulletSection(_ title: String, _ rows: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(row)
                        .font(.subheadline)
                        .foregroundStyle(Color.signalMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveButton(_ story: StoryDetail) -> some View {
        Button {
            savedStoriesStore.toggle(savedSummary(from: story))
        } label: {
            Label(
                savedStoriesStore.contains(story.id) ? "Saved" : "Save story",
                systemImage: savedStoriesStore.contains(story.id) ? "bookmark.fill" : "bookmark"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(.signalInk)
        .calmScrollReveal()
    }

    private func savedSummary(from story: StoryDetail) -> StorySummary {
        todayViewModel.storySummary(id: story.id) ?? StorySummary(
            id: story.id,
            headline: story.headline,
            region: story.region,
            category: story.category,
            summary: story.whatHappened,
            whyItMatters: story.whyItMatters,
            confidence: story.confidence.rating,
            emotionalLoad: story.emotionalLoad,
            sourceCount: story.sources.count,
            imageId: nil
        )
    }

    private func actionGrid(_ story: StoryDetail) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                detailLink("Evidence Check", "checkmark.shield", nil, .evidenceCheck(story.id))
                detailLink("Sources", "doc.text", nil, .sources(story.id))
            }
            GridRow {
                detailLink("Framing", "book", nil, .biasExplanation(story.id))
                detailLink("Depth", "square.stack.3d.up", "\(todayViewModel.depthTokenStatus.remaining) left", .depthAnalysis(story.id))
            }
        }
        .calmScrollReveal()
    }

    private func detailLink(_ title: String, _ image: String, _ subtitle: String?, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            ActionTile(title: title, systemImage: image, subtitle: subtitle)
        }
        .buttonStyle(.plain)
    }
}
