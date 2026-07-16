import SwiftUI

extension Color {
    static let signalBackground = Color(red: 0.978, green: 0.969, blue: 0.946)
    static let signalSurface = Color(red: 1.0, green: 0.997, blue: 0.982)
    static let signalInk = Color(red: 0.102, green: 0.137, blue: 0.149)
    static let signalMuted = Color(red: 0.392, green: 0.427, blue: 0.424)
    static let signalLine = Color(red: 0.852, green: 0.831, blue: 0.782)
    static let signalSage = Color(red: 0.392, green: 0.525, blue: 0.414)
    static let signalClay = Color(red: 0.711, green: 0.439, blue: 0.329)
    static let signalOchre = Color(red: 0.746, green: 0.496, blue: 0.108)
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.signalBackground.ignoresSafeArea())
    }
}

extension View {
    func signalScreen() -> some View {
        modifier(ScreenBackground())
    }

    func signalCard() -> some View {
        padding(16)
            .background(Color.signalSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.signalLine.opacity(0.8), lineWidth: 1)
            )
    }

    func signalInsetPanel() -> some View {
        background(Color.signalSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.signalLine.opacity(0.8), lineWidth: 1)
            )
    }

    func signalGlassCard(cornerRadius: CGFloat = 18) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.signalSurface.opacity(0.52))
                LinearGradient(
                    colors: [
                        .white.opacity(0.36),
                        .white.opacity(0.08),
                        Color.signalSage.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.62), .white.opacity(0.08), Color.signalSage.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.signalInk.opacity(0.18), lineWidth: 1.2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: 1.5)
                .stroke(Color.signalLine.opacity(0.62), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: 1)
                .stroke(Color.white.opacity(0.42), lineWidth: 0.7)
        )
        .shadow(color: Color.signalInk.opacity(0.035), radius: 18, x: 0, y: 10)
    }

    func calmScrollReveal() -> some View {
        scrollTransition(.interactive.threshold(.visible(0.28))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.18)
                .blur(radius: phase.isIdentity ? 0 : 1.4)
                .scaleEffect(phase.isIdentity ? 1 : 0.985)
                .offset(y: phase.isIdentity ? 0 : 10)
        }
    }

    func calmLetterScrollReveal(index: Int) -> some View {
        scrollTransition(
            .animated(.easeInOut(duration: 0.18).delay(CalmTextTiming.letterDelay(index: index, step: 0.006, maximum: 0.08)))
        ) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.08)
                .blur(radius: phase.isIdentity ? 0 : 0.9)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                .offset(y: phase.isIdentity ? 0 : 4)
        }
    }
}

enum CalmTextTiming {
    static func letterDelay(index: Int, step: Double = 0.012, maximum: Double = 0.22) -> Double {
        min(Double(index) * step, maximum)
    }
}

enum GlassDeckLayout {
    static let cardWidthRatio = 0.95
    static let activeScale = 1.015
    static let inactiveScale = 0.96
    static let inactiveOpacity = 0.68
    static let inactiveBlur = 0.5
    static let topOffset: CGFloat = 18
    static let showsSwipeCue = true
    static let swipeCueDotCount = 3
    static let showsQueueLabel = false
    static let showsQueueSummary = false
    static let showsCardOrdinal = false

    static func swipeCueActiveDotIndex(focusedIndex: Int, total: Int) -> Int {
        guard total > 1 else { return 0 }
        return max(focusedIndex, 0) % swipeCueDotCount
    }
}

enum SavedStoriesLayout {
    static let emptyStateTopPadding: CGFloat = 76
}

enum BriefingStatusText {
    static let moreInformationAction = "More information"
    static let doneAction = "Done"
    static let commentAction = "Comment"
    static let atAGlanceTitle = "At a glance"
    static let evidenceTitle = "Evidence and uncertainty"
    static let framingTitle = "Framing and sources"

    static func cardOrdinal(index: Int, total: Int) -> String {
        "\(String(format: "%02d", max(index, 1))) / \(String(format: "%02d", max(total, 1)))"
    }

    static func queueSummary(cardCount: Int, readingTimeMinutes: Int) -> String {
        "\(cardCount) cards · \(readingTimeMinutes) min"
    }

    static func progress(read: Int, total: Int) -> String {
        "\(read) of \(max(total, 0)) read"
    }

    static func depthTokens(remaining: Int, allowed: Int) -> String {
        "\(remaining)/\(max(allowed, 0))"
    }
}

enum PopupArticleLayout {
    static let maxChromeWidth: CGFloat = 368
    static let maxChromeHeight: CGFloat = 684
    static let sectionSpacing: CGFloat = 18
    static let bodyLineSpacing: CGFloat = 4
    static let usesSummaryForLead = true
    static let leadSectionUsesInnerCard = false
    static let reportedDetailStartsExpanded = false
}

enum PopupCopy {
    static func cleaned(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CascadingText: View {
    let text: String
    var font: Font = .title
    var color: Color = .signalInk
    var alignment: Alignment = .center
    var textAlignment: TextAlignment = .center

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 5)
                    .animation(
                        .easeOut(duration: 0.26).delay(CalmTextTiming.letterDelay(index: index)),
                        value: isVisible
                    )
                    .calmLetterScrollReveal(index: index)
            }
        }
        .font(font)
        .foregroundStyle(color)
        .multilineTextAlignment(textAlignment)
        .frame(maxWidth: .infinity, alignment: alignment)
        .onAppear {
            isVisible = true
        }
    }
}

struct MetadataPill: View {
    let text: String
    var tint: Color = .signalSage

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct CalmButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.signalInk)
    }
}

struct SignalTopBar: View {
    let title: String
    var trailingSystemImage: String? = nil
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Color.clear
                .frame(width: SignalTopBarLayout.controlSize, height: SignalTopBarLayout.controlSize)
            Spacer(minLength: 0)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.signalInk)
            Spacer(minLength: 0)
            if let trailingSystemImage {
                Button {
                    trailingAction?()
                } label: {
                    Image(systemName: trailingSystemImage)
                        .font(.title3)
                        .frame(width: SignalTopBarLayout.controlSize, height: SignalTopBarLayout.controlSize)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.signalInk)
            } else {
                Color.clear.frame(width: SignalTopBarLayout.controlSize, height: SignalTopBarLayout.controlSize)
            }
        }
    }
}

enum SignalTopBarLayout {
    static let controlSize: CGFloat = 36
}

struct SignalIconTile: View {
    let systemImage: String
    var tint: Color = .signalSage

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.medium))
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SignalMetric: View {
    let systemImage: String
    let text: String
    var tint: Color = .signalMuted

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
    }
}

struct ActionTile: View {
    let title: String
    let systemImage: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.signalInk)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalInk)
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .padding(10)
        .signalInsetPanel()
    }
}

struct EvidenceStrengthBar: View {
    let level: Int

    private let labels = ["Very weak", "Weak", "Moderate", "Strong", "Very strong"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < level ? Color.signalOchre : Color.signalLine.opacity(0.75))
                        .frame(height: 9)
                }
            }
            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(Color.signalMuted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.signalSage)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .signalScreen()
    }
}
