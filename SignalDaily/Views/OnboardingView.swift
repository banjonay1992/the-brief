import SwiftUI

struct OnboardingView: View {
    var onComplete: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .center, spacing: 10) {
                    CascadingText(
                        text: "The Brief",
                        font: .system(size: 40, weight: .regular, design: .serif),
                        color: .signalInk
                    )
                    Text("News without the nervous breakdown.")
                        .font(.title3)
                        .foregroundStyle(Color.signalMuted)
                        .multilineTextAlignment(.center)
                    Text("One calm briefing each day, with evidence checks, source transparency, and no infinite feed.")
                        .font(.subheadline)
                        .foregroundStyle(Color.signalMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .signalGlassCard(tint: .signalPowder)

                VStack(alignment: .leading, spacing: 14) {
                    principle("Evidence before alignment", "Claims are attributed and confidence is based on verification, not geopolitical familiarity.")
                    principle("A clear ending", "The briefing finishes. There is no infinite scroll and no recommendation tunnel.")
                    principle("Equal scrutiny", "States, armed groups, officials, NGOs, companies, and media outlets are judged by the same standards.")
                }

                NavigationLink(value: AppRoute.preferencesSetup) {
                    Label("Set up your briefing", systemImage: "slider.horizontal.3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.signalInk)

                if let onComplete {
                    Button {
                        onComplete()
                    } label: {
                        Label("Start today’s briefing", systemImage: "newspaper")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.signalInk)
                }
            }
            .padding(20)
        }
        .signalScreen()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func principle(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Color.signalMuted)
        }
        .signalCard()
    }
}
