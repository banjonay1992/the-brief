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
                    VStack(alignment: .leading, spacing: 20) {
                        storyHeader(story, accent: accent)
                        leadPanel(story, accent: accent)
                        evidencePanel(story, accent: accent)
                        actionGrid(story)
                        saveButton(story)
                    }
                    .padding(20)
                    .padding(.bottom, 28)
                }
                .background(alignment: .top) {
                    Circle()
                        .fill(accent.opacity(0.14))
                        .frame(width: 340, height: 340)
                        .blur(radius: 70)
                        .offset(y: -140)
                        .accessibilityHidden(true)
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
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
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

    private func evidencePanel(_ story: StoryDetail, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            detailSection("What we know", accent: .signalSage) {
                bulletList(story.whatWeKnow, tint: .signalSage)
            }

            Rectangle()
                .fill(Color.signalLine.opacity(0.6))
                .frame(height: 1)

            detailSection("What is unclear", accent: .signalOchre) {
                bulletList(story.whatIsUnclear, tint: .signalOchre)
            }

            Rectangle()
                .fill(Color.signalLine.opacity(0.6))
                .frame(height: 1)

            detailSection("Evidence confidence", accent: .signalPowderDeep) {
                HStack(alignment: .top, spacing: 12) {
                    Text(story.confidence.reason)
                        .font(.subheadline)
                        .lineSpacing(3)
                        .foregroundStyle(Color.signalMuted)
                    Spacer(minLength: 0)
                    MetadataPill(text: story.confidence.rating.rawValue, tint: .signalPowderDeep)
                }
            }
        }
        .padding(18)
        .signalInsetPanel()
        .calmScrollReveal()
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
