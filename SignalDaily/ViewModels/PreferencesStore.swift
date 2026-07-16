import Foundation
import Observation

@MainActor
@Observable
final class PreferencesStore {
    var preferences: UserPreferences

    private let service: BriefingServing
    private let userDefaults: UserDefaults
    private let storageKey: String

    init(
        preferences: UserPreferences? = nil,
        service: BriefingServing = MockBriefingService(),
        userDefaults: UserDefaults = .standard,
        storageKey: String = "userPreferences"
    ) {
        self.service = service
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.preferences = preferences ?? Self.loadPreferences(userDefaults: userDefaults, storageKey: storageKey)
    }

    func toggleRegion(_ region: String) {
        toggle(region, in: \.regions)
    }

    func toggleTopic(_ topic: String) {
        toggle(topic, in: \.topics)
    }

    func save() async {
        persist()
        try? await service.savePreferences(preferences)
    }

    func persist() {
        if let data = try? SignalJSON.encoder.encode(preferences) {
            userDefaults.set(data, forKey: storageKey)
        }
    }

    private func toggle(_ value: String, in keyPath: WritableKeyPath<UserPreferences, [String]>) {
        if preferences[keyPath: keyPath].contains(value) {
            preferences[keyPath: keyPath].removeAll { $0 == value }
        } else {
            preferences[keyPath: keyPath].append(value)
        }
        persist()
    }

    private static func loadPreferences(userDefaults: UserDefaults, storageKey: String) -> UserPreferences {
        guard
            let data = userDefaults.data(forKey: storageKey),
            let preferences = try? SignalJSON.decoder.decode(UserPreferences.self, from: data)
        else {
            return .defaults
        }
        return preferences
    }
}
