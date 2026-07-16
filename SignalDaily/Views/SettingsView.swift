import SwiftUI

struct SettingsView: View {
    @Bindable var preferencesStore: PreferencesStore
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(AuthStore.self) private var authStore

    var body: some View {
        Form {
            Section("Account") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(authStore.userDisplayName)
                        .font(.headline)
                    if let email = authStore.session?.user.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(Color.signalMuted)
                    }
                }

                Button("Sign out", role: .destructive) {
                    Task { await authStore.signOut() }
                }
            }

            Section("Subscription") {
                HStack {
                    Text("The Brief Plus")
                    Spacer()
                    Text(subscriptionStore.accessState.label)
                        .foregroundStyle(Color.signalMuted)
                }
                NavigationLink("Manage subscription", value: AppRoute.subscription)
            }
            Section("Briefing") {
                Picker("Mode", selection: $preferencesStore.preferences.briefingMode) {
                    ForEach(BriefingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Stepper("Max stories: \(preferencesStore.preferences.maxStories)", value: $preferencesStore.preferences.maxStories, in: 5...30)
                Toggle("Low-intensity default", isOn: $preferencesStore.preferences.lowIntensityDefault)
            }
            Section("Notifications") {
                Toggle("One daily reminder", isOn: $preferencesStore.preferences.dailyReminderEnabled)
                Text("Critical alerts are off by default and should remain extremely strict.")
                    .font(.footnote)
                    .foregroundStyle(Color.signalMuted)
            }
            Section("Transparency") {
                Toggle("Show framing checks", isOn: $preferencesStore.preferences.showFramingChecks)
                Toggle("Show source confidence explanations", isOn: $preferencesStore.preferences.showConfidenceReasons)
                NavigationLink("Bias and framing rules", value: AppRoute.biasExplanation("story_001"))
                Button("Save settings") {
                    Task { await preferencesStore.save() }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.signalBackground)
        .navigationTitle("Settings")
    }
}
