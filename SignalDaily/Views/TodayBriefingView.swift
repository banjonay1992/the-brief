import SwiftUI

struct TodayBriefingView: View {
    @Environment(SavedStoriesStore.self) private var savedStoriesStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(ReadingLedger.self) private var readingLedger
    @Bindable var viewModel: TodayViewModel
    var openSettings: () -> Void = {}
    @State private var activePopup: StoryPopup?
    @State private var showsSubscriptionPrompt = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SignalTopBar(title: "The Brief", trailingSystemImage: "gearshape") {
                    openSettings()
                }
                    .calmScrollReveal()
                header
                stateBanner
                if let briefing = viewModel.briefing {
                    ReadingThread(
                        total: briefing.allStories.count,
                        read: viewModel.readableStoryCount
                    )
                    .padding(.horizontal, 6)

                    StoryQueueCarousel(
                        stories: viewModel.storyQueue(savedStoryIDs: Set(savedStoriesStore.savedStoryIDs)),
                        readingTimeMinutes: briefing.readingTimeMinutes,
                        threadInfo: threadInfo(for: briefing),
                        completion: completionSummary(for: briefing),
                        onMoreInformation: { story in
                            activePopup = StoryPopup(kind: .information, story: story)
                            Task {
                                await viewModel.loadStory(id: story.id)
                            }
                        },
                        onDone: { story in
                            withAnimation(.easeInOut(duration: 0.24)) {
                                viewModel.markRead(story.id)
                            }
                            readingLedger.recordRead(story, briefingDate: briefing.date)
                            recordCompletionIfSealed()
                            if viewModel.shouldPromptForSubscription(hasAccess: subscriptionStore.accessState.hasAccess) {
                                showsSubscriptionPrompt = true
                            }
                        },
                        onComment: { story in
                            activePopup = StoryPopup(kind: .comment, story: story)
                        }
                    )
                }
            }
            .padding(20)
        }
        .signalScreen()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.readableStoryCount)
        .sensoryFeedback(.success, trigger: readingLedger.calmMorningCount)
        .task {
            await viewModel.loadToday()
            await subscriptionStore.refresh()
            syncLedgerWithBriefing()
        }
        .onChange(of: viewModel.briefing) { _, _ in
            syncLedgerWithBriefing()
        }
        .sheet(isPresented: $showsSubscriptionPrompt) {
            NavigationStack {
                SubscriptionView(subscriptionStore: subscriptionStore)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Not now") {
                                showsSubscriptionPrompt = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
        }
        .overlay {
            if let activePopup {
                Group {
                    switch activePopup.kind {
                    case .information:
                        StoryInformationPopup(
                            story: activePopup.story,
                            detail: viewModel.storyDetail(id: activePopup.story.id)
                        ) {
                            self.activePopup = nil
                        }
                    case .comment:
                        StoryCommentPopup(story: activePopup.story) {
                            self.activePopup = nil
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activePopup?.id)
    }

    private var header: some View {
        VStack(alignment: .center, spacing: 8) {
            CascadingText(
                text: "Today’s Briefing",
                font: .system(size: 36, weight: .regular, design: .serif),
                color: .signalInk
            )
            Text(headerDateText)
                .font(.headline)
                .foregroundStyle(Color.signalInk)
                .multilineTextAlignment(.center)
            Text("One calm global pass. Evidence first, no infinite feed.")
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
            CalmMorningsBadge(count: readingLedger.calmMorningCount)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncLedgerWithBriefing() {
        guard let briefing = viewModel.briefing else { return }
        readingLedger.noteSeen(stories: briefing.allStories, briefingDate: briefing.date)
        viewModel.hydrateReadStories(readingLedger.readStoryIDs(briefingDate: briefing.date))
        recordCompletionIfSealed()
    }

    private func recordCompletionIfSealed() {
        guard let briefing = viewModel.briefing else { return }
        let queue = viewModel.storyQueue(savedStoryIDs: Set(savedStoriesStore.savedStoryIDs))
        if queue.isEmpty && viewModel.readableStoryCount > 0 {
            readingLedger.recordCompletedMorning(briefingDate: briefing.date)
        }
    }

    private func threadInfo(for briefing: Briefing) -> [String: StoryThreadInfo] {
        var result: [String: StoryThreadInfo] = [:]
        for story in briefing.allStories {
            let update = viewModel.updates?.updates.first { $0.storyId == story.id }
            let day = readingLedger.threadDayNumber(storyID: story.id, briefingDate: briefing.date)
                .flatMap { $0 >= 2 ? $0 : nil }
            if update != nil || day != nil {
                result[story.id] = StoryThreadInfo(dayNumber: day, note: update?.whatChanged)
            }
        }
        return result
    }

    private func completionSummary(for briefing: Briefing) -> CompletionSummary {
        CompletionSummary(
            storyCount: viewModel.readableStoryCount,
            minutes: briefing.readingTimeMinutes,
            calmMornings: readingLedger.calmMorningCount
        )
    }

    @ViewBuilder
    private var stateBanner: some View {
        switch viewModel.loadingState {
        case .idle, .loading:
            HStack {
                ProgressView()
                Text("Preparing your briefing.")
                    .foregroundStyle(Color.signalMuted)
            }
            .signalCard()
        case .offlineCached:
            Label("You’re viewing the last downloaded briefing. Some source links may not open until you’re back online.", systemImage: "wifi.slash")
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .signalCard()
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(Color.signalClay)
                .signalCard()
        case .loaded:
            EmptyView()
        }
    }

}

private extension TodayBriefingView {
    var headerDateText: String {
        let dateText = viewModel.briefing?.date ?? Date.now.formatted(.iso8601.year().month().day())
        guard let date = Self.headerDateFormatter.date(from: dateText) else {
            return dateText
        }
        return date.formatted(.dateTime.day().month(.wide).year())
    }

    static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

}

struct StoryThreadInfo: Equatable {
    let dayNumber: Int?
    let note: String?
}

struct CompletionSummary: Equatable {
    let storyCount: Int
    let minutes: Int
    let calmMornings: Int
}

private struct StoryQueueCarousel: View {
    let stories: [StorySummary]
    let readingTimeMinutes: Int
    let threadInfo: [String: StoryThreadInfo]
    let completion: CompletionSummary
    let onMoreInformation: (StorySummary) -> Void
    let onDone: (StorySummary) -> Void
    let onComment: (StorySummary) -> Void
    @State private var focusedStoryID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if GlassDeckLayout.showsQueueLabel || GlassDeckLayout.showsQueueSummary {
                HStack(spacing: 9) {
                    if GlassDeckLayout.showsQueueLabel {
                        Circle()
                            .fill(Color.signalOchre)
                            .frame(width: 7, height: 7)
                        Text("LATEST FIRST")
                            .font(.caption.weight(.semibold))
                            .tracking(2.0)
                            .foregroundStyle(Color.signalSage)
                    }
                    Spacer()
                    if GlassDeckLayout.showsQueueSummary {
                        Text(BriefingStatusText.queueSummary(cardCount: stories.count, readingTimeMinutes: readingTimeMinutes))
                            .font(.caption)
                            .foregroundStyle(Color.signalMuted)
                    }
                }
                .padding(.horizontal, 4)
            }

            if stories.isEmpty {
                BriefingQueueCompleteCard(summary: completion)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                GeometryReader { proxy in
                    let cardWidth = proxy.size.width * GlassDeckLayout.cardWidthRatio
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                                VStack(spacing: 12) {
                                    LeadStoryGlassCard(
                                        story: story,
                                        index: index + 1,
                                        total: stories.count,
                                        threadInfo: threadInfo[story.id],
                                        onMoreInformation: {
                                            onMoreInformation(story)
                                        },
                                        onDone: {
                                            onDone(story)
                                        },
                                        onComment: {
                                            onComment(story)
                                        }
                                    )
                                }
                                .frame(width: cardWidth)
                                .scrollTransition(.interactive.threshold(.visible(0.72))) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : GlassDeckLayout.inactiveOpacity)
                                        .scaleEffect(phase.isIdentity ? GlassDeckLayout.activeScale : GlassDeckLayout.inactiveScale)
                                        .blur(radius: phase.isIdentity ? 0 : GlassDeckLayout.inactiveBlur)
                                        .offset(y: phase.isIdentity ? -2 : 5)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $focusedStoryID)
                    .contentMargins(.horizontal, max((proxy.size.width - cardWidth) / 2, 0), for: .scrollContent)
                    .scrollIndicators(.hidden)
                }
                .frame(height: 430)

                if GlassDeckLayout.showsSwipeCue {
                    SwipeCueView(
                        focusedIndex: focusedStoryIndex,
                        total: stories.count
                    )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, GlassDeckLayout.topOffset)
        .animation(.easeInOut(duration: 0.24), value: stories.map(\.id))
        .onAppear {
            focusedStoryID = focusedStoryID ?? stories.first?.id
        }
        .onChange(of: stories) { _, newStories in
            if focusedStoryID == nil || !newStories.contains(where: { $0.id == focusedStoryID }) {
                focusedStoryID = newStories.first?.id
            }
        }
    }

    private var focusedStoryIndex: Int {
        guard let focusedStoryID,
              let index = stories.firstIndex(where: { $0.id == focusedStoryID })
        else {
            return 0
        }
        return index
    }
}

private struct SwipeCueView: View {
    let focusedIndex: Int
    let total: Int

    var body: some View {
        let activeDotIndex = GlassDeckLayout.swipeCueActiveDotIndex(
            focusedIndex: focusedIndex,
            total: total
        )

        HStack(spacing: 7) {
            Image(systemName: "chevron.left")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.signalMuted.opacity(focusedIndex > 0 ? 0.42 : 0.16))

            HStack(spacing: 5) {
                ForEach(0..<GlassDeckLayout.swipeCueDotCount, id: \.self) { index in
                    Capsule()
                        .fill(index == activeDotIndex ? Color.signalSage.opacity(0.58) : Color.signalLine.opacity(0.72))
                        .frame(width: index == activeDotIndex ? 18 : 6, height: 6)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.signalMuted.opacity(focusedIndex < max(total - 1, 0) ? 0.42 : 0.16))
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.18), value: activeDotIndex)
        .accessibilityHidden(true)
    }
}

private struct LeadStoryGlassCard: View {
    let story: StorySummary
    let index: Int
    let total: Int
    var threadInfo: StoryThreadInfo? = nil
    let onMoreInformation: () -> Void
    let onDone: () -> Void
    let onComment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 15) {
                if GlassDeckLayout.showsCardOrdinal {
                    Text(BriefingStatusText.cardOrdinal(index: index, total: total))
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(Color.signalMuted.opacity(0.78))
                }

                if let threadInfo {
                    StoryThreadMarker(info: threadInfo)
                }

                Text(story.headline)
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(Color.signalInk)
                    .lineSpacing(1)
                    .lineLimit(4)
                    .minimumScaleFactor(0.82)

                VStack(alignment: .leading, spacing: 6) {
                    Text(story.summary)
                        .lineLimit(2)
                    Text(story.whyItMatters)
                        .lineLimit(2)
                }
                .font(.system(size: 15))
                .lineSpacing(2)
                .foregroundStyle(Color.signalMuted)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onMoreInformation)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text("\(story.region) · \(story.category)")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.signalSage)

                Rectangle()
                    .fill(Color.signalInk.opacity(0.14))
                    .frame(height: 1)

                HStack(spacing: 16) {
                    Text(story.confidence.rawValue)
                        .foregroundStyle(Color.signalSage)
                    Rectangle()
                        .fill(Color.signalLine.opacity(0.75))
                        .frame(width: 1, height: 22)
                    Text(story.sourceCountText)
                        .foregroundStyle(Color.signalMuted)
                    Spacer()
                }
                .font(.subheadline.weight(.medium))

                HStack(spacing: 10) {
                    GlassTapButton(
                        title: BriefingStatusText.doneAction,
                        systemImage: "checkmark",
                        action: {}
                    )
                    .allowsHitTesting(false)

                    GlassTapButton(
                        title: BriefingStatusText.commentAction,
                        systemImage: "text.bubble",
                        action: {}
                    )
                    .allowsHitTesting(false)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 25)
        .frame(maxWidth: .infinity, minHeight: 410, maxHeight: 410, alignment: .leading)
        .signalGlassCard()
        .overlay {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if value.location.y > proxy.size.height - 110 {
                                    value.location.x < proxy.size.width / 2 ? onDone() : onComment()
                                } else {
                                    onMoreInformation()
                                }
                            }
                    )
            }
        }
        .accessibilityLabel("\(story.headline). \(story.sourceCountText). Confidence \(story.confidence.rawValue).")
    }
}

private struct StoryThreadMarker: View {
    let info: StoryThreadInfo

    var body: some View {
        HStack(spacing: 8) {
            Text(markerLabel)
                .font(.caption2.weight(.semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.signalClay)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.signalPeach.opacity(0.55), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.signalPeach, lineWidth: 1)
                )

            if let note = info.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.signalMuted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var markerLabel: String {
        if let day = info.dayNumber {
            return RitualCopy.threadMarker(day: day)
        }
        return "Continuing"
    }
}

private struct BriefingQueueCompleteCard: View {
    let summary: CompletionSummary

    var body: some View {
        VStack(spacing: 0) {
            SealBadge()
                .padding(.bottom, 18)

            Text(RitualCopy.sealedTitle)
                .font(.system(size: 30, weight: .regular, design: .serif))
                .foregroundStyle(Color.signalInk)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)

            Text(RitualCopy.sealedSubtitle)
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            Text(RitualCopy.sealedTally(storyCount: summary.storyCount, minutes: summary.minutes))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.signalMuted)
                .monospacedDigit()

            CalmMorningsBadge(count: summary.calmMornings)
                .padding(.top, 8)

            Rectangle()
                .fill(Color.signalPowderDeep.opacity(0.30))
                .frame(width: 44, height: 1)
                .padding(.vertical, 16)

            Text(RitualCopy.nextBriefLine)
                .font(.footnote)
                .foregroundStyle(Color.signalMuted.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 28)
        .signalGlassCard(tint: .signalPowder)
    }
}

private struct GlassTapButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .foregroundStyle(Color.signalInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .padding(.horizontal, 10)
                .contentShape(Capsule())
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Color.signalSurface.opacity(0.42), in: Capsule())
                }
                .overlay(
                    Capsule()
                        .stroke(Color.signalInk.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct StoryInformationPopup: View {
    let story: StorySummary
    let detail: StoryDetail?
    let onClose: () -> Void
    private var matchingDetail: StoryDetail? {
        guard detail?.id == story.id else { return nil }
        return detail
    }

    var body: some View {
        StoryPopupChrome(onClose: onClose) {
            ScrollView {
                VStack(alignment: .leading, spacing: PopupArticleLayout.sectionSpacing) {
                    PopupHeader(title: BriefingStatusText.moreInformationAction, onClose: onClose)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(PopupCopy.cleaned(matchingDetail?.headline ?? story.headline))
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .lineSpacing(3)
                            .foregroundStyle(Color.signalInk)
                            .fixedSize(horizontal: false, vertical: true)

                        PopupMetadataStrip(
                            region: matchingDetail?.region ?? story.region,
                            confidence: matchingDetail?.confidence.rating.rawValue ?? story.confidence.rawValue,
                            emotionalLoad: matchingDetail?.emotionalLoad.rawValue ?? story.emotionalLoad.rawValue
                        )

                        PopupSourceLine(
                            sourceCountText: story.sourceCountText,
                            confidence: matchingDetail?.confidence.rating.rawValue ?? story.confidence.rawValue
                        )
                    }

                    PopupLeadReading(
                        atAGlance: story.summary,
                        whyItMatters: story.whyItMatters
                    )

                    if let detail = matchingDetail {
                        PopupDisclosureSection(
                            title: "Reported detail",
                            initiallyExpanded: PopupArticleLayout.reportedDetailStartsExpanded
                        ) {
                            PopupReadableText(detail.whatHappened)
                        }

                        PopupDisclosureSection(title: BriefingStatusText.evidenceTitle) {
                            if let verification = detail.verification {
                                PopupVerificationSection(verification: verification)
                            }
                            PopupListSection(title: "What we know", items: detail.whatWeKnow)
                            PopupListSection(title: "What is unclear", items: detail.whatIsUnclear)
                            PopupSection(title: "Confidence", text: detail.confidence.reason)
                        }

                        PopupDisclosureSection(title: BriefingStatusText.framingTitle) {
                            PopupFramingSection(framingCheck: detail.framingCheck)
                            PopupSourceSection(sources: detail.sources)
                            PopupListSection(title: "Bias audit", items: detail.biasAudit.notes)
                        }
                    } else {
                        PopupSection(
                            title: "Confidence",
                            text: "Confidence is currently \(story.confidence.rawValue). Full source notes will appear when the article detail finishes loading."
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 28)
                .id("\(story.id)-\(matchingDetail?.id ?? "summary")")
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct StoryCommentPopup: View {
    let story: StorySummary
    let onClose: () -> Void
    @State private var comment = ""

    var body: some View {
        StoryPopupChrome(onClose: onClose) {
            VStack(alignment: .leading, spacing: 18) {
                PopupHeader(title: BriefingStatusText.commentAction, onClose: onClose)

                Text(story.headline)
                    .font(.system(size: 22, weight: .regular, design: .serif))
                    .lineSpacing(2)
                    .foregroundStyle(Color.signalInk)

                Text("Private note for your own context. This is not a public comment thread.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .lineSpacing(2)

                TextEditor(text: $comment)
                    .font(.subheadline)
                    .foregroundStyle(Color.signalInk)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(minHeight: 150)
                    .background(Color.signalSurface.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.signalInk.opacity(0.13), lineWidth: 1)
                    )

                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.signalSurface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.signalInk, in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture(perform: onClose)
            }
            .padding(24)
        }
    }
}

private struct StoryPopupChrome<Content: View>: View {
    let onClose: () -> Void
    let content: Content

    init(onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            content
                .frame(
                    maxWidth: PopupArticleLayout.maxChromeWidth,
                    maxHeight: PopupArticleLayout.maxChromeHeight,
                    alignment: .top
                )
                .signalGlassCard(cornerRadius: 24)
                .overlay(alignment: .topTrailing) {
                    Color.clear
                        .frame(width: 76, height: 76)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onClose)
                }
                .padding(.horizontal, 14)
        }
    }
}

private struct PopupHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Color.signalSage)
                .textCase(.uppercase)
            Spacer()
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.signalInk)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.signalInk.opacity(0.14), lineWidth: 1)
                )
                .contentShape(Circle())
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Close")
        }
    }
}

private struct PopupSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.signalInk)
            PopupReadableText(text)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PopupLeadReading: View {
    let atAGlance: String
    let whyItMatters: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PopupSection(title: BriefingStatusText.atAGlanceTitle, text: atAGlance)

            Divider()
                .overlay(Color.signalLine.opacity(0.48))

            PopupSection(title: "Why it matters", text: whyItMatters)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PopupReadableText: View {
    let text: String

    init(_ text: String) {
        self.text = PopupCopy.cleaned(text)
    }

    var body: some View {
        Text(text)
            .font(.callout)
            .lineSpacing(PopupArticleLayout.bodyLineSpacing)
            .foregroundStyle(Color.signalMuted)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.disabled)
    }
}

private struct PopupSourceLine: View {
    let sourceCountText: String
    let confidence: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalSage)
            Text("\(sourceCountText) · \(confidence) confidence")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.signalMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopupMetadataStrip: View {
    let region: String
    let confidence: String
    let emotionalLoad: String

    var body: some View {
        HStack(spacing: 8) {
            PopupSoftPill(text: region)
            PopupSoftPill(text: confidence)
            PopupSoftPill(text: emotionalLoad)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
}

private struct PopupSoftPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.signalSage)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.signalSage.opacity(0.10), in: Capsule())
    }
}

private struct PopupQuietPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
        .background(Color.signalSurface.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.signalLine.opacity(0.42), lineWidth: 1)
        )
    }
}

private struct PopupDisclosureSection<Content: View>: View {
    let title: String
    @State private var isExpanded: Bool
    @ViewBuilder var content: Content

    init(title: String, initiallyExpanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        _isExpanded = State(initialValue: initiallyExpanded)
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(.top, 12)
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.signalInk)
        }
        .tint(Color.signalSage)
        .padding(.vertical, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.signalLine.opacity(0.40))
                .frame(height: 1)
        }
        .id(title)
    }
}

private struct PopupListSection: View {
    let title: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.signalInk)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(Color.signalOchre.opacity(0.78))
                                .frame(width: 4, height: 4)
                                .padding(.top, 7)
                            Text(item)
                                .font(.caption)
                                .lineSpacing(3)
                                .foregroundStyle(Color.signalMuted)
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PopupVerificationSection: View {
    let verification: StoryVerification

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Verification")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalInk)
            Text(verification.summary)
                .font(.caption)
                .lineSpacing(3)
                .foregroundStyle(Color.signalMuted)
            PopupListSection(title: "Checks", items: verification.checks)
        }
    }
}

private struct PopupFramingSection: View {
    let framingCheck: FramingCheck

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Framing check")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalInk)
            PopupFramingRow(label: "Western/mainstream", text: framingCheck.westernMainstream)
            PopupFramingRow(label: "Local/regional", text: framingCheck.localRegional)
            PopupFramingRow(label: "Official", text: framingCheck.officialGovernment)
            PopupFramingRow(label: "Affected people", text: framingCheck.affectedPopulation)
            PopupFramingRow(label: "Independent evidence", text: framingCheck.independentEvidence)
            if let humanRightsNGO = framingCheck.humanRightsNGO {
                PopupFramingRow(label: "Human rights / NGO", text: humanRightsNGO)
            }
            if let opposingSide = framingCheck.opposingSide {
                PopupFramingRow(label: "Opposing side", text: opposingSide)
            }
        }
    }
}

private struct PopupFramingRow: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalSage)
            Text(text)
                .font(.caption)
                .lineSpacing(2)
                .foregroundStyle(Color.signalMuted)
        }
    }
}

private struct PopupSourceSection: View {
    let sources: [Source]

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sources")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.signalInk)
                ForEach(sources.prefix(4)) { source in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(source.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.signalInk)
                        Text("\(source.type) · \(source.region)")
                            .font(.caption2)
                            .foregroundStyle(Color.signalMuted)
                    }
                }
            }
        }
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(Color.signalMuted)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.signalInk)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}

private struct StoryPopup: Identifiable, Equatable {
    enum Kind: String {
        case information
        case comment
    }

    let kind: Kind
    let story: StorySummary

    var id: String {
        "\(kind.rawValue)-\(story.id)"
    }
}


struct StoryCardView: View {
    let story: StorySummary

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            VStack(alignment: .center, spacing: 6) {
                Text(story.headline)
                    .font(.headline)
                    .foregroundStyle(Color.signalInk)
                    .multilineTextAlignment(.center)
                Text("\(story.region) · \(story.category)")
                    .font(.caption)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                MetadataPill(text: story.confidence.rawValue)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .center, spacing: 6) {
                Text("What happened:")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(story.summary)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                Text("Why it matters:")
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(story.whyItMatters)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Spacer()
                MetadataPill(text: story.emotionalLoad.rawValue, tint: story.emotionalLoad == .heavy ? .signalClay : .signalSage)
                MetadataPill(text: story.sourceCountText, tint: .signalMuted)
                Spacer()
            }

            NavigationLink(value: AppRoute.story(story.id)) {
                Label("Go deeper", systemImage: "arrow.right.circle")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .signalCard()
    }
}
