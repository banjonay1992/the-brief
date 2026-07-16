import SwiftUI

struct EvidenceCheckView: View {
    @Environment(TodayViewModel.self) private var todayViewModel
    let storyID: String

    private var check: EvidenceCheck? {
        todayViewModel.evidenceCheck(id: storyID)
    }

    var body: some View {
        Group {
            if let check {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Evidence Check")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .calmScrollReveal()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Claim")
                            .font(.headline)
                        Text(check.claim)
                            .foregroundStyle(Color.signalMuted)
                    }
                    .signalCard()
                    .calmScrollReveal()
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SignalIconTile(systemImage: "questionmark", tint: .signalOchre)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Classification")
                                    .font(.headline)
                                Text(check.classification.rawValue)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Color.signalOchre)
                            }
                            Spacer()
                        }
                        Text(check.why)
                            .foregroundStyle(Color.signalMuted)
                    }
                    .signalCard()
                    .calmScrollReveal()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Evidence strength")
                                .font(.headline)
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.signalMuted)
                        }
                        EvidenceStrengthBar(level: strengthLevel(for: check.classification))
                    }
                    .signalCard()
                    .calmScrollReveal()
                    VStack(alignment: .leading, spacing: 8) {
                        Label("We classify claims based on available evidence, source quality, and verification status. Classifications can change as new evidence emerges.", systemImage: "lightbulb")
                            .font(.footnote)
                            .foregroundStyle(Color.signalMuted)
                    }
                    .signalCard()
                    .calmScrollReveal()
                }
                .padding(20)
                .padding(.bottom, 24)
                .signalScreen()
            } else {
                EmptyStateView(
                    title: "No evidence check yet",
                    message: "This story does not have a claim-level evidence check attached.",
                    systemImage: "checkmark.shield"
                )
            }
        }
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await todayViewModel.loadStory(id: storyID) }
    }

    private func strengthLevel(for classification: EvidenceClassification) -> Int {
        switch classification {
        case .confirmed:
            5
        case .plausibleUnconfirmed:
            3
        case .speculative:
            1
        case .narrativeTrap, .likelyFalse:
            1
        }
    }
}
