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

    /// The only two pastels in the app, used semantically:
    /// powder = settled and kept (progress, the seal, the library),
    /// peach = alive and moving (continuing stories, the streak).
    static let signalPowder = Color(red: 0.678, green: 0.792, blue: 0.882)
    static let signalPowderDeep = Color(red: 0.404, green: 0.573, blue: 0.729)
    static let signalPeach = Color(red: 0.984, green: 0.827, blue: 0.718)
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.signalBackground.ignoresSafeArea())
    }
}

/// The sky the app lives under. Five gentle phases across the day —
/// the ritual should look like the hour it happens in.
enum DayPhase: CaseIterable {
    case dawn, morning, afternoon, evening, night

    static func current(hour: Int = Calendar.current.component(.hour, from: .now)) -> DayPhase {
        switch hour {
        case 5..<8: .dawn
        case 8..<12: .morning
        case 12..<17: .afternoon
        case 17..<21: .evening
        default: .night
        }
    }

    var gradient: [Color] {
        switch self {
        case .dawn: [
            Color(red: 0.973, green: 0.898, blue: 0.847),
            Color(red: 0.976, green: 0.945, blue: 0.895),
            Color.signalBackground
        ]
        case .morning: [
            Color(red: 0.879, green: 0.925, blue: 0.937),
            Color(red: 0.945, green: 0.949, blue: 0.918),
            Color.signalBackground
        ]
        case .afternoon: [
            Color(red: 0.965, green: 0.937, blue: 0.847),
            Color(red: 0.973, green: 0.957, blue: 0.906),
            Color.signalBackground
        ]
        case .evening: [
            Color(red: 0.933, green: 0.867, blue: 0.833),
            Color(red: 0.914, green: 0.894, blue: 0.914),
            Color.signalBackground
        ]
        case .night: [
            Color(red: 0.827, green: 0.867, blue: 0.914),
            Color(red: 0.914, green: 0.914, blue: 0.898),
            Color.signalBackground
        ]
        }
    }

    var orb: Color {
        switch self {
        case .dawn: Color(red: 0.976, green: 0.749, blue: 0.596)
        case .morning: Color(red: 0.667, green: 0.808, blue: 0.871)
        case .afternoon: Color(red: 0.949, green: 0.827, blue: 0.545)
        case .evening: Color(red: 0.925, green: 0.694, blue: 0.573)
        case .night: Color(red: 0.769, green: 0.816, blue: 0.894)
        }
    }

    var secondaryOrb: Color {
        switch self {
        case .dawn: Color.signalPowder
        case .morning: Color(red: 0.918, green: 0.882, blue: 0.769)
        case .afternoon: Color.signalPeach
        case .evening: Color(red: 0.780, green: 0.741, blue: 0.831)
        case .night: Color(red: 0.851, green: 0.831, blue: 0.769)
        }
    }

    var tagline: String {
        switch self {
        case .dawn: "The early edition. The world can wait for coffee."
        case .morning: "One calm global pass. Evidence first, no infinite feed."
        case .afternoon: "The afternoon edition. Still no infinite feed."
        case .evening: "The evening edition. Read it, seal it, rest."
        case .night: "The late edition. Tomorrow is already on its way."
        }
    }
}

/// Soft sky gradient with two blurred light orbs. Sits behind glass
/// so every card picks up a little of the hour's colour.
struct AtmosphereBackground: View {
    var phase: DayPhase = .current()
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            LinearGradient(colors: phase.gradient, startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(phase.orb.opacity(0.50 * intensity))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 120, y: -300)
            Circle()
                .fill(phase.secondaryOrb.opacity(0.38 * intensity))
                .frame(width: 360, height: 360)
                .blur(radius: 95)
                .offset(x: -150, y: 220)
            RippleField(opacityScale: 0.65 + 0.35 * intensity)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Raindrops on a still lake: every few seconds a drop lands somewhere
/// and sends out three slow rings that fade as they widen. Drawn on a
/// Canvas so the whole effect is a handful of strokes per frame.
/// Sits out entirely when Reduce Motion is on.
struct RippleField: View {
    var tint: Color = .white
    var dropInterval: Double = 5.5
    var opacityScale: Double = 1.0
    @State private var born = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let rippleLife = 5.0

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(born) + 2.5
                    guard elapsed > 0 else { return }
                    let life = Self.rippleLife
                    let firstIndex = max(0, Int((elapsed - life) / dropInterval))
                    let lastIndex = max(firstIndex, Int(elapsed / dropInterval))
                    for index in firstIndex...lastIndex {
                        let spawn = Double(index) * dropInterval + jitter(index, 3) * dropInterval * 0.7
                        let age = elapsed - spawn
                        guard age > 0, age < life else { continue }
                        let x = (0.10 + 0.80 * jitter(index, 1)) * size.width
                        let y = (0.08 + 0.74 * jitter(index, 2)) * size.height
                        for ring in 0..<3 {
                            let ringDelay = Double(ring) * 0.55
                            let progress = (age - ringDelay) / (life - ringDelay)
                            guard progress > 0, progress < 1 else { continue }
                            let eased = 1 - pow(1 - progress, 2.2)
                            let radius = 8 + eased * 165
                            let alpha = pow(1 - progress, 1.7) * 0.55 * opacityScale
                            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                            context.stroke(
                                Circle().path(in: rect),
                                with: .color(tint.opacity(alpha)),
                                lineWidth: max(1.1, 3.6 - eased * 2.2)
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Deterministic 0..1 noise per drop so the rain has no schedule state.
    private func jitter(_ index: Int, _ salt: Int) -> Double {
        let raw = sin(Double(index &* 127 &+ salt &* 311) * 12.9898) * 43758.5453
        return raw - raw.rounded(.down)
    }
}

/// The water itself. When a drop lands: the sky underneath gets a true
/// per-pixel ripple (Metal displacement — pure SwiftUI layers only, since
/// shader effects can't rasterize UIKit-backed views like ScrollView), and
/// the UI above gets a damped physical sway — a small lift, tilt, and
/// settle synced to the same wave. Ambient drops fall every few seconds;
/// screens can land one on demand (marking a story done). Reduce Motion
/// stills the water completely.
struct CalmWaterModifier: ViewModifier {
    var atmosphereIntensity: Double = 1.0
    /// Bump to land a drop at `dropPoint` (unit coordinates).
    var dropTrigger: Int = 0
    var dropPoint: UnitPoint = UnitPoint(x: 0.5, y: 0.45)

    @State private var origin = UnitPoint(x: 0.5, y: 0.4)
    @State private var dropStart: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let waveLife: TimeInterval = 2.6
    private let ambientTimer = Timer.publish(every: 8.5, on: .main, in: .common).autoconnect()

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: pausedNow)) { timeline in
                let time = activeTime(at: timeline.date)
                let envelope = reduceMotion ? 0 : exp(-1.9 * time)
                let wave = sin(8.5 * time) * envelope
                let settle = sin(6.0 * time + 0.9) * envelope
                content
                    .offset(y: wave * 3.2)
                    .rotationEffect(.degrees(settle * 0.35), anchor: .init(x: origin.x, y: origin.y))
                    .scaleEffect(1 + wave * 0.0035, anchor: .center)
                    .background {
                        AtmosphereBackground(intensity: atmosphereIntensity)
                            .distortionEffect(
                                ShaderLibrary.calmRipple(
                                    .float2(origin.x * proxy.size.width, origin.y * proxy.size.height),
                                    .float(time),
                                    .float(reduceMotion ? 0 : 14),
                                    .float(11),
                                    .float(2.1),
                                    .float(1300)
                                ),
                                maxSampleOffset: CGSize(width: 16, height: 16)
                            )
                    }
            }
        }
        .onReceive(ambientTimer) { _ in
            guard !reduceMotion else { return }
            origin = UnitPoint(x: .random(in: 0.15...0.85), y: .random(in: 0.12...0.75))
            dropStart = Date()
        }
        .onChange(of: dropTrigger) { _, _ in
            guard !reduceMotion else { return }
            origin = dropPoint
            dropStart = Date()
        }
    }

    private var pausedNow: Bool {
        guard !reduceMotion, let dropStart else { return true }
        return Date().timeIntervalSince(dropStart) > Self.waveLife
    }

    private func activeTime(at date: Date) -> Double {
        guard let dropStart else { return Self.waveLife }
        return min(max(date.timeIntervalSince(dropStart), 0), Self.waveLife)
    }
}

extension View {
    /// Sits the screen on water: supplies the atmosphere background with a
    /// true ripple distortion, sways the UI with each drop, and lands an
    /// on-demand drop whenever `drop` changes. Replaces `signalAtmosphere`.
    func calmWater(
        intensity: Double = 1.0,
        drop: Int = 0,
        at point: UnitPoint = UnitPoint(x: 0.5, y: 0.45)
    ) -> some View {
        modifier(CalmWaterModifier(atmosphereIntensity: intensity, dropTrigger: drop, dropPoint: point))
    }
}

/// Every category gets a quiet accent so the deck shifts colour as it turns.
enum CategoryStyle {
    static func tint(for category: String) -> Color {
        let key = category.lowercased()
        if key.contains("conflict") || key.contains("security") || key.contains("politic") || key.contains("justice") {
            return .signalClay
        }
        if key.contains("climate") || key.contains("environment") || key.contains("energy") || key.contains("weather") {
            return .signalSage
        }
        if key.contains("science") || key.contains("tech") || key.contains("health") || key.contains("space") {
            return .signalPowderDeep
        }
        if key.contains("econom") || key.contains("business") || key.contains("market") || key.contains("finance") || key.contains("trade") {
            return .signalOchre
        }
        let palette: [Color] = [.signalSage, .signalOchre, .signalPowderDeep, .signalClay]
        let seed = category.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }
}

extension View {
    func signalScreen() -> some View {
        modifier(ScreenBackground())
    }

    /// Browsing surfaces live under the sky; reading surfaces stay cream.
    func signalAtmosphere(intensity: Double = 1.0) -> some View {
        background(AtmosphereBackground(intensity: intensity))
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

    func signalGlassCard(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.signalSurface.opacity(0.52))
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.20))
                }
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
    static let topOffset: CGFloat = 6
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

@MainActor
enum BriefDate {
    /// "2026-05-17" → "17 May 2026"; falls back to the raw string.
    static func display(_ isoDay: String) -> String {
        guard let date = ReadingLedger.dayFormatter.date(from: isoDay) else { return isoDay }
        return date.formatted(.dateTime.day().month(.wide).year())
    }
}

enum RitualCopy {
    static let sealedTitle = "Today is sealed."
    static let sealedSubtitle = "Nothing more is asked of you."
    static let nextBriefLine = "The next brief arrives tomorrow morning."

    static func calmMornings(_ count: Int) -> String {
        count == 1 ? "1 calm morning" : "\(count) calm mornings"
    }

    static func sealedTally(storyCount: Int, minutes: Int) -> String {
        let stories = storyCount == 1 ? "1 story" : "\(storyCount) stories"
        return "\(stories) · about \(max(minutes, 1)) min"
    }

    static func threadMarker(day: Int) -> String {
        "Day \(day)"
    }

    static func libraryTally(stories: Int, days: Int) -> String {
        let storyText = stories == 1 ? "1 story" : "\(stories) stories"
        let dayText = days == 1 ? "1 day" : "\(days) days"
        return "\(storyText) across \(dayText)"
    }
}

/// A quiet reading-progress line: one slender segment per story,
/// filling as cards are marked done. No numbers shouting, no rings.
struct ReadingThread: View {
    let total: Int
    let read: Int

    /// Above this, one segment per story stops being legible (and the rigid
    /// inter-segment spacing would force the layout wider than the screen),
    /// so the thread becomes a single continuous line.
    private static let segmentLimit = 16

    var body: some View {
        if total > 0 {
            HStack(spacing: 10) {
                if total <= Self.segmentLimit {
                    HStack(spacing: 4) {
                        ForEach(0..<total, id: \.self) { index in
                            Capsule()
                                .fill(index < read ? Color.signalPowderDeep.opacity(0.85) : Color.signalLine.opacity(0.7))
                                .frame(height: 3.5)
                        }
                    }
                } else {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.signalLine.opacity(0.7))
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.signalPowderDeep.opacity(0.85))
                                .frame(width: proxy.size.width * CGFloat(min(read, total)) / CGFloat(total))
                        }
                    }
                    .frame(height: 3.5)
                }
                Text("\(read) of \(total)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.signalMuted.opacity(0.85))
                    .monospacedDigit()
                    .fixedSize()
            }
            .animation(.easeInOut(duration: 0.35), value: read)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(read) of \(total) stories read")
        }
    }
}

/// The streak, worn quietly: a peach capsule, never a fire emoji.
struct CalmMorningsBadge: View {
    let count: Int

    var body: some View {
        if count >= 2 {
            Text(RitualCopy.calmMornings(count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalClay)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.signalPeach.opacity(0.55), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.signalPeach, lineWidth: 1)
                )
        }
    }
}

/// The completion seal: a slow-drawn ring around a serif monogram.
/// Deliberately unhurried — the reward is the sense of closure, not fireworks.
struct SealBadge: View {
    var size: CGFloat = 74
    @State private var isDrawn = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.signalPowder.opacity(0.35))
            Circle()
                .trim(from: 0, to: isDrawn ? 1 : 0)
                .stroke(Color.signalPowderDeep.opacity(0.85), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .inset(by: 5)
                .stroke(Color.signalPowderDeep.opacity(0.35), lineWidth: 0.8)
            Text("B")
                .font(.system(size: size * 0.42, weight: .regular, design: .serif))
                .foregroundStyle(Color.signalPowderDeep)
                .opacity(isDrawn ? 1 : 0)
                .scaleEffect(isDrawn ? 1 : 0.85)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) {
                isDrawn = true
            }
        }
        .accessibilityHidden(true)
    }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .opacity(isVisible || reduceMotion ? 1 : 0)
                    .blur(radius: isVisible || reduceMotion ? 0 : 1.6)
                    .offset(y: isVisible || reduceMotion ? 0 : 5)
                    .animation(
                        .easeOut(duration: 0.34).delay(CalmTextTiming.letterDelay(index: index)),
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

/// Per-word fade-in for text that has to wrap: each word settles into
/// place with a soft blur and rise, a beat after the one before it.
struct CalmWordsText: View {
    let text: String
    var font: Font
    var color: Color = .signalInk
    var wordSpacing: CGFloat = 6
    var lineSpacing: CGFloat = 3
    var maxCharacters: Int? = nil

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var words: [String] {
        let display: String
        if let maxCharacters, text.count > maxCharacters {
            let prefix = String(text.prefix(maxCharacters))
            let cut = prefix.lastIndex(of: " ").map { String(prefix[..<$0]) } ?? prefix
            display = cut + "…"
        } else {
            display = text
        }
        return display.split(separator: " ").map(String.init)
    }

    var body: some View {
        FlowLayout(spacing: wordSpacing, lineSpacing: lineSpacing) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(font)
                    .foregroundStyle(color)
                    .opacity(isVisible || reduceMotion ? 1 : 0)
                    .blur(radius: isVisible || reduceMotion ? 0 : 2.0)
                    .offset(y: isVisible || reduceMotion ? 0 : 7)
                    .animation(
                        .easeOut(duration: 0.5).delay(Double(index) * 0.055),
                        value: isVisible
                    )
            }
        }
        .onAppear {
            isVisible = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Minimal left-aligned wrapping layout so CalmWordsText can animate
/// word views individually while still flowing like a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        frames(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = frames(maxWidth: bounds.width, subviews: subviews)
        for (frame, view) in zip(layout.frames, subviews) {
            view.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(maxWidth: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (frames, CGSize(width: widest, height: y + lineHeight))
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
