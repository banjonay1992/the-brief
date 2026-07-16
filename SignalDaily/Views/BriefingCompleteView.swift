import SwiftUI

struct BriefingCompleteView: View {
    let briefing: Briefing?

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(Color.signalSage.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .frame(width: 104, height: 104)
                Circle()
                    .fill(Color.signalSage)
                    .frame(width: 82, height: 82)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.signalSurface)
            }

            CascadingText(
                text: "You’re caught up",
                font: .system(size: 34, weight: .regular, design: .serif),
                color: .signalInk
            )
            CascadingText(
                text: "for today.",
                font: .system(size: 34, weight: .regular, design: .serif),
                color: .signalInk
            )

            Rectangle()
                .fill(Color.signalSage)
                .frame(width: 74, height: 3)
                .clipShape(Capsule())

            if let briefing {
                completionRow("book", "You read", "\(briefing.storyCount) stories in \(briefing.readingTimeMinutes) minutes.")
            }
            completionRow("checkmark.shield", "No major update requires", "your attention right now.")
            completionRow("leaf", "Go live", "your actual life.")

            Spacer()

            HStack(spacing: 12) {
                SignalIconTile(systemImage: "calendar")
                VStack(alignment: .leading, spacing: 3) {
                    Text("See you tomorrow")
                        .font(.headline)
                    Text("Your next briefing will arrive at 8:00 AM")
                        .font(.caption)
                        .foregroundStyle(Color.signalMuted)
                }
                Spacer()
            }
            .signalCard()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .signalScreen()
        .navigationTitle("Complete")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    private func completionRow(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(spacing: 16) {
            SignalIconTile(systemImage: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                Text(body)
                    .font(.headline)
                    .foregroundStyle(Color.signalInk)
            }
            Spacer()
        }
        .frame(maxWidth: 285)
    }
}
