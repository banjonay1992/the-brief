import SwiftUI

/// The reading archive: every story ever finished, kept locally and grouped
/// by day. The collection only grows — a quiet reason to keep the ritual.
struct LibraryView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    @Environment(ReadingLedger.self) private var readingLedger

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                CascadingText(
                    text: "Library",
                    font: .system(size: 34, weight: .semibold, design: .serif),
                    color: .signalInk
                )

                Text("Everything you’ve finished, kept quietly. It only grows.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)

                if readingLedger.totalReadCount == 0 {
                    EmptyLibraryCard()
                        .padding(.top, 18)
                } else {
                    LibraryTallyCard(
                        stories: readingLedger.totalReadCount,
                        days: readingLedger.readingDayCount,
                        calmMornings: readingLedger.calmMorningCount
                    )
                    .calmScrollReveal()

                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(readingLedger.recordsByDay, id: \.date) { day in
                            LibraryDayHeader(date: day.date)
                                .padding(.top, 12)
                            ForEach(day.records) { record in
                                LibraryStoryRow(
                                    record: record,
                                    isNavigable: todayViewModel.storySummary(id: record.id) != nil
                                )
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(20)
            .padding(.top, readingLedger.totalReadCount == 0 ? SavedStoriesLayout.emptyStateTopPadding : 34)
        }
        .signalScreen()
        .navigationTitle("Library")
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await todayViewModel.loadToday() }
    }
}

private struct LibraryTallyCard: View {
    let stories: Int
    let days: Int
    let calmMornings: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("\(stories)")
                .font(.system(size: 44, weight: .regular, design: .serif))
                .foregroundStyle(Color.signalPowderDeep)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(RitualCopy.libraryTally(stories: stories, days: days))
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)

            CalmMorningsBadge(count: calmMornings)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .signalGlassCard(tint: .signalPowder)
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryDayHeader: View {
    let date: String

    var body: some View {
        Text(displayText)
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.signalSage)
            .padding(.horizontal, 4)
    }

    private var displayText: String {
        let todayText = ReadingLedger.dayFormatter.string(from: .now)
        if date == todayText {
            return "Today"
        }
        guard let parsed = ReadingLedger.dayFormatter.date(from: date) else {
            return date
        }
        return parsed.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct LibraryStoryRow: View {
    let record: ReadStoryRecord
    let isNavigable: Bool

    var body: some View {
        if isNavigable {
            NavigationLink(value: AppRoute.story(record.id)) {
                rowContent
            }
            .buttonStyle(.plain)
            .calmScrollReveal()
        } else {
            rowContent
                .calmScrollReveal()
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.signalSage)
                .frame(width: 26, height: 26)
                .background(Color.signalSage.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(record.story.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.signalInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(record.story.region) · \(record.story.category)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.signalSage)

                HStack(spacing: 8) {
                    Text(record.story.confidence.rawValue)
                    Text(record.story.sourceCountText)
                }
                .font(.caption)
                .foregroundStyle(Color.signalMuted)
            }

            Spacer(minLength: 0)

            if isNavigable {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.signalMuted.opacity(0.45))
                    .padding(.top, 5)
            }
        }
        .padding(14)
        .background(Color.signalSurface.opacity(0.74), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.signalLine.opacity(0.74), lineWidth: 1)
        )
    }
}

private struct EmptyLibraryCard: View {
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Your library starts today")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Every story you finish is kept here, day by day. Clear today’s briefing to place the first one on the shelf.")
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .signalCard()
        .calmScrollReveal()
    }
}
