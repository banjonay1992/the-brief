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
                let accent = CategoryStyle.tint(for: story.category)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        storyHeader(story, accent: accent)
                        leadPanel(story, accent: accent)
                        evidenceCard(story)
                        linksCard(story)
                        saveButton(story)
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
            } else {
                EmptyStateView(
                    title: "Opening the story",
                    message: "Fetching the full evidence notes.",
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .task(id: storyID) {
            todayViewModel.markRead(storyID)
            await todayViewModel.loadStory(id: storyID)
        }
        .signalScreen()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func storyHeader(_ story: StoryDetail, accent: Color) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Text(StoryKicker.text(region: story.region, category: story.category))
                .font(.caption.weight(.semibold))
                .tracking(2.2)
                .textCase(.uppercase)
                .foregroundStyle(accent)

            CalmWordsText(
                text: story.headline,
                font: .system(size: 28, weight: .medium, design: .serif),
                wordSpacing: 7,
                lineSpacing: 4
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                if let briefingDate = todayViewModel.briefing?.date {
                    SignalMetric(systemImage: "calendar", text: BriefDate.display(briefingDate))
                }
                SignalMetric(
                    systemImage: "checkmark.seal",
                    text: story.sources.count == 1 ? "1 source" : "\(story.sources.count) sources"
                )
                Spacer()
                MetadataPill(
                    text: intensityText(story.emotionalLoad),
                    tint: story.emotionalLoad == .heavy || story.emotionalLoad == .graphic ? .signalClay : .signalSage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Circle()
                .fill(accent.opacity(0.13))
                .frame(width: 320, height: 320)
                .blur(radius: 75)
                .offset(y: -60)
                .accessibilityHidden(true)
        }
    }

    private func intensityText(_ load: EmotionalLoad) -> String {
        switch load {
        case .low: "Low intensity"
        case .medium: "Medium intensity"
        case .heavy: "Heavy intensity"
        case .graphic: load.rawValue
        }
    }

    private func leadPanel(_ story: StoryDetail, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            detailSection("What happened", accent: accent) {
                Text(story.whatHappened)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(Color.signalInk.opacity(0.82))
            }

            Rectangle()
                .fill(accent.opacity(0.25))
                .frame(height: 1)

            detailSection("Why it matters", accent: accent) {
                Text(story.whyItMatters)
                    .font(.system(size: 15, design: .serif).italic())
                    .lineSpacing(3)
                    .foregroundStyle(Color.signalInk.opacity(0.75))
            }
        }
        .padding(18)
        .background(Color.signalSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
        .calmScrollReveal()
    }

    private func evidenceCard(_ story: StoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Evidence")
                    .font(.caption.weight(.semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.signalPowderDeep)
                Spacer()
                MetadataPill(text: story.confidence.rating.rawValue, tint: .signalPowderDeep)
            }

            Text(story.confidence.reason)
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(Color.signalMuted)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 14) {
                    detailSection("What we know", accent: .signalSage) {
                        bulletList(story.whatWeKnow, tint: .signalSage)
                    }
                    detailSection("What is unclear", accent: .signalOchre) {
                        bulletList(story.whatIsUnclear, tint: .signalOchre)
                    }
                }
                .padding(.top, 12)
            } label: {
                Text("What we know · what is unclear")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.signalInk)
            }
            .tint(Color.signalSage)
            .padding(.top, 2)
        }
        .padding(18)
        .signalInsetPanel()
        .calmScrollReveal()
    }

    private func linksCard(_ story: StoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            linkRow("Evidence check", "checkmark.shield", nil, .evidenceCheck(story.id))
            rowDivider
            linkRow("Sources", "doc.text", nil, .sources(story.id))
            rowDivider
            linkRow("Framing", "book", nil, .biasExplanation(story.id))
            rowDivider
            linkRow("Depth", "square.stack.3d.up", "\(todayViewModel.depthTokenStatus.remaining) left", .depthAnalysis(story.id))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .signalInsetPanel()
        .calmScrollReveal()
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.signalLine.opacity(0.5))
            .frame(height: 1)
    }

    private func linkRow(_ title: String, _ image: String, _ value: String?, _ route: AppRoute) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Image(systemName: image)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.signalSage)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.signalInk)
                Spacer()
                if let value {
                    Text(value)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.signalMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.signalMuted.opacity(0.5))
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func detailSection(_ title: String, accent: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bulletList(_ rows: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(row)
                        .font(.subheadline)
                        .lineSpacing(2)
                        .foregroundStyle(Color.signalMuted)
                }
            }
        }
    }

    private func saveButton(_ story: StoryDetail) -> some View {
        Button {
            savedStoriesStore.toggle(savedSummary(from: story))
        } label: {
            Label(
                savedStoriesStore.contains(story.id) ? "Saved" : "Save story",
                systemImage: savedStoriesStore.contains(story.id) ? "bookmark.fill" : "bookmark"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .foregroundStyle(savedStoriesStore.contains(story.id) ? Color.signalPowderDeep : Color.signalInk)
        .background(
            savedStoriesStore.contains(story.id) ? Color.signalPowder.opacity(0.35) : Color.signalSurface.opacity(0.9),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    savedStoriesStore.contains(story.id) ? Color.signalPowder : Color.signalInk.opacity(0.18),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.18), value: savedStoriesStore.contains(story.id))
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

}
