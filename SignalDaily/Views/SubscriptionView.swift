import SwiftUI

struct SubscriptionView: View {
    @Bindable var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                CascadingText(
                    text: SubscriptionCopy.title,
                    font: .system(size: 34, weight: .regular, design: .serif),
                    color: .signalInk
                )

                Text(SubscriptionCopy.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                planCard

                VStack(spacing: 10) {
                    CalmButton(
                        title: subscriptionStore.accessState.hasAccess ? "Subscribed" : "Start monthly subscription",
                        systemImage: subscriptionStore.accessState.hasAccess ? "checkmark.seal" : "creditcard"
                    ) {
                        Task { await subscriptionStore.purchaseMonthly() }
                    }
                    .disabled(subscriptionStore.isWorking || subscriptionStore.accessState.hasAccess)

                    Button {
                        Task { await subscriptionStore.restorePurchases() }
                    } label: {
                        Label("Restore purchases", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.signalInk)
                    .disabled(subscriptionStore.isWorking)
                }

                if subscriptionStore.isWorking {
                    ProgressView()
                        .tint(.signalSage)
                }

                if let message = subscriptionStore.message {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.signalMuted)
                        .multilineTextAlignment(.center)
                }

                Text(SubscriptionCopy.reviewNote)
                    .font(.caption)
                    .foregroundStyle(Color.signalMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .signalScreen()
        .navigationTitle("Subscription")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.signalBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await subscriptionStore.refresh()
        }
    }

    private var planCard: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 12) {
                SignalIconTile(systemImage: "newspaper.fill", tint: .signalSage)
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionStore.primaryProduct.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.signalInk)
                    Text(subscriptionStore.primaryProduct.displayPrice)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.signalSage)
                }
                Spacer()
                MetadataPill(text: subscriptionStore.accessState.label, tint: subscriptionStore.accessState.hasAccess ? .signalSage : .signalMuted)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Daily global briefing", systemImage: "checkmark")
                Label("Evidence checks and framing notes", systemImage: "checkmark")
                Label("Finite calm updates, no infinite feed", systemImage: "checkmark")
            }
            .font(.subheadline)
            .foregroundStyle(Color.signalMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .signalCard()
        .calmScrollReveal()
    }
}
