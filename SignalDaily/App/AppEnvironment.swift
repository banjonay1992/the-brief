import Foundation

struct AppEnvironment: Sendable {
    enum Mode: Equatable, Sendable {
        case mock
        case api(URL)
    }

    let mode: Mode

    static var current: AppEnvironment {
        let bundle = Bundle.main
        let useMocks = boolValue(bundle.object(forInfoDictionaryKey: "SignalDailyUseMocks"), default: true)
        let urlString = bundle.object(forInfoDictionaryKey: "SignalDailyAPIBaseURL") as? String
        let apiURL = urlString.flatMap(URL.init(string:)) ?? URL(string: "http://127.0.0.1:8787")!
        return useMocks ? AppEnvironment(mode: .mock) : AppEnvironment(mode: .api(apiURL))
    }

    var briefingService: BriefingServing {
        switch mode {
        case .mock:
            MockBriefingService()
        case .api(let url):
            BriefingAPIClient(baseURL: url)
        }
    }

    var authService: AuthServicing {
        switch mode {
        case .mock:
            MockAuthService()
        case .api(let url):
            AuthAPIClient(baseURL: url)
        }
    }

    var subscriptionService: SubscriptionServicing {
        StoreKitSubscriptionService()
    }

    static func boolValue(_ value: Any?, default defaultValue: Bool) -> Bool {
        if let bool = value as? Bool {
            return bool
        }
        if let string = value as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "yes", "true", "1":
                return true
            case "no", "false", "0":
                return false
            default:
                return defaultValue
            }
        }
        return defaultValue
    }
}
