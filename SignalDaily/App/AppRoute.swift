import Foundation

enum AppRoute: Hashable {
    case onboarding
    case preferencesSetup
    case section(String)
    case story(String)
    case evidenceCheck(String)
    case depthAnalysis(String)
    case sources(String)
    case biasExplanation(String)
    case subscription
    case complete
}

enum AppTab: String, CaseIterable, Identifiable {
    case today
    case done
    case saved
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .done: "Done"
        case .saved: "Saved"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "newspaper"
        case .done: "checkmark.circle"
        case .saved: "bookmark"
        case .settings: "gearshape"
        }
    }
}
