import SwiftUI

struct OnboardingView: View {
    var onComplete: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to The Brief")
                        .font(.largeTitle.bold())
                    Text("News without the nervous breakdown.")
                        .font(.title3)
                        .foregroundStyle(Color.signalMuted)
                    Text("Get one calm briefing each day, with evidence checks, source transparency, and no infinite feed.")
                        .foregroundStyle(Color.signalMuted)
                }
                .signalCard()

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
        .navigationTitle("Onboarding")
        .navigationBarTitleDisplayMode(.inline)
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
