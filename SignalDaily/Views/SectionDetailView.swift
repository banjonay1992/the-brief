import SwiftUI

struct SectionDetailView: View {
    let section: BriefingSection?

    var body: some View {
        Group {
            if let section {
                ScrollView {
                    LazyVStack(alignment: .center, spacing: 14) {
                        CascadingText(
                            text: section.title,
                            font: .system(size: 34, weight: .semibold, design: .serif),
                            color: .signalInk
                        )
                        ForEach(section.stories) { story in
                            StoryCardView(story: story)
                                .calmScrollReveal()
                        }
                    }
                    .padding(20)
                }
                .signalScreen()
            } else {
                EmptyStateView(
                    title: "This section is empty",
                    message: "The briefing may still be preparing, or this section has no stories today.",
                    systemImage: "tray"
                )
            }
        }
        .navigationTitle(section?.title ?? "Section")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
