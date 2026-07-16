import Foundation

enum SignalSubscriptionProduct {
    static let monthly = "the_brief_monthly"
    static let all = [monthly]
}

enum SubscriptionAccessState: Equatable, Sendable {
    case checking
    case subscribed
    case unsubscribed
    case unavailable(String)

    var hasAccess: Bool {
        switch self {
        case .subscribed:
            true
        case .checking, .unsubscribed, .unavailable:
            false
        }
    }

    var label: String {
        switch self {
        case .checking:
            "Checking subscription"
        case .subscribed:
            "Active"
        case .unsubscribed:
            "Not subscribed"
        case .unavailable:
            "Unavailable"
        }
    }
}

struct SubscriptionDisplayProduct: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let description: String
}

enum SubscriptionCopy {
    static let title = "The Brief Plus"
    static let subtitle = "One calm global briefing each day, source transparency, framing checks, and finite updates."
    static let monthlyPriceFallback = "£0.99 / month"
    static let reviewNote = "Subscription renews monthly. You can cancel any time in App Store settings."
}
