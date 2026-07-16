import SwiftUI

struct PreferencesSetupView: View {
    @Bindable var preferencesStore: PreferencesStore
    var onComplete: (() -> Void)?

    private let regions = ["World", "UK", "US", "Middle East", "Europe", "Africa", "Asia", "Latin America"]
    private let topics = ["Conflict", "Science", "Technology", "Economy", "Climate", "Health", "Humanitarian", "Progress"]

    var body: some View {
        Form {
            Section("Regions") {
                multiSelect(values: regions, selected: preferencesStore.preferences.regions) { region in
                    preferencesStore.toggleRegion(region)
                }
            }
            Section("Topics") {
                multiSelect(values: topics, selected: preferencesStore.preferences.topics) { topic in
                    preferencesStore.toggleTopic(topic)
                }
            }
            Section("Briefing intensity") {
                Picker("Mode", selection: $preferencesStore.preferences.briefingMode) {
                    ForEach(BriefingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Stepper("Max stories: \(preferencesStore.preferences.maxStories)", value: $preferencesStore.preferences.maxStories, in: 5...30)
                Toggle("Hide graphic topics by default", isOn: $preferencesStore.preferences.lowIntensityDefault)
            }
            Section("Daily reminder") {
                Toggle("Enable daily reminder", isOn: $preferencesStore.preferences.dailyReminderEnabled)
                DatePicker(
                    "Preferred time",
                    selection: Binding(
                        get: { timeDate(preferencesStore.preferences.dailyReminderTime) },
                        set: { preferencesStore.preferences.dailyReminderTime = timeString($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            Section("Transparency") {
                Toggle("Include progress section", isOn: $preferencesStore.preferences.includeProgressSection)
                Toggle("Show framing checks", isOn: $preferencesStore.preferences.showFramingChecks)
                Toggle("Show confidence reasons", isOn: $preferencesStore.preferences.showConfidenceReasons)
                Toggle("Show graphic content", isOn: $preferencesStore.preferences.showGraphicContent)
            }
            Section {
                Button("Save preferences") {
                    Task {
                        await preferencesStore.save()
                        onComplete?()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.signalBackground)
        .navigationTitle("Preferences")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    Task {
                        await preferencesStore.save()
                        onComplete?()
                    }
                }
            }
        }
    }

    private func multiSelect(values: [String], selected: [String], action: @escaping (String) -> Void) -> some View {
        ForEach(values, id: \.self) { value in
            Button {
                action(value)
            } label: {
                HStack {
                    Text(value)
                        .foregroundStyle(Color.signalInk)
                    Spacer()
                    if selected.contains(value) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.signalSage)
                    }
                }
            }
        }
    }

    private func timeDate(_ string: String) -> Date {
        let parts = string.split(separator: ":").compactMap { Int($0) }
        return Calendar.current.date(bySettingHour: parts.first ?? 8, minute: parts.dropFirst().first ?? 0, second: 0, of: Date()) ?? Date()
    }

    private func timeString(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 8, components.minute ?? 0)
    }
}
