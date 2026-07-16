import SwiftUI

struct SettingsView: View {
    @Bindable var preferencesStore: PreferencesStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CascadingText(
                    text: "Settings",
                    font: .system(size: 34, weight: .semibold, design: .serif),
                    color: .signalInk
                )

                Text("Changes save themselves. Nothing here shouts.")
                    .font(.subheadline)
                    .foregroundStyle(Color.signalMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                settingsSection("Account") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authStore.userDisplayName)
                            .font(.headline)
                            .foregroundStyle(Color.signalInk)
                        if let email = authStore.session?.user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(Color.signalMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    settingsDivider

                    Button("Sign out", role: .destructive) {
                        Task { await authStore.signOut() }
                    }
                    .font(.subheadline.weight(.medium))
                    .tint(.signalClay)
                }

                settingsSection("Subscription") {
                    HStack {
                        Text("The Brief Plus")
                            .foregroundStyle(Color.signalInk)
                        Spacer()
                        Text(subscriptionStore.accessState.label)
                            .foregroundStyle(Color.signalMuted)
                    }
                    .font(.subheadline)

                    settingsDivider

                    NavigationLink(value: AppRoute.subscription) {
                        settingsLinkRow("Manage subscription")
                    }
                    .buttonStyle(.plain)
                }

                settingsSection("Briefing") {
                    HStack {
                        Text("Mode")
                            .font(.subheadline)
                            .foregroundStyle(Color.signalInk)
                        Spacer()
                        Picker("Mode", selection: $preferencesStore.preferences.briefingMode) {
                            ForEach(BriefingMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.signalSage)
                    }

                    settingsDivider

                    Stepper(value: $preferencesStore.preferences.maxStories, in: 5...30) {
                        Text("Max stories: \(preferencesStore.preferences.maxStories)")
                            .font(.subheadline)
                            .foregroundStyle(Color.signalInk)
                            .monospacedDigit()
                    }

                    settingsDivider

                    calmToggle("Low-intensity default", isOn: $preferencesStore.preferences.lowIntensityDefault)
                }

                settingsSection("Notifications") {
                    calmToggle("One daily reminder", isOn: $preferencesStore.preferences.dailyReminderEnabled)

                    Text("Critical alerts are off by default and should remain extremely strict.")
                        .font(.footnote)
                        .foregroundStyle(Color.signalMuted)
                }

                settingsSection("Transparency") {
                    calmToggle("Show framing checks", isOn: $preferencesStore.preferences.showFramingChecks)

                    settingsDivider

                    calmToggle("Show source confidence explanations", isOn: $preferencesStore.preferences.showConfidenceReasons)

                    settingsDivider

                    NavigationLink(value: AppRoute.biasExplanation(nil)) {
                        settingsLinkRow("How framing checks work")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .signalAtmosphere(intensity: 0.45)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: preferencesStore.preferences) { _, _ in
            Task { await preferencesStore.save() }
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.signalLine.opacity(0.55))
            .frame(height: 1)
    }

    private func settingsLinkRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.signalInk)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.signalMuted.opacity(0.5))
        }
        .contentShape(Rectangle())
    }

    private func calmToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.subheadline)
            .foregroundStyle(Color.signalInk)
            .tint(Color.signalSage)
    }

    @ViewBuilder
    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color.signalSage)

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(16)
            .signalInsetPanel()
        }
    }
}
