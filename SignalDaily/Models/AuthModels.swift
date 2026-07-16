import Foundation

struct AuthUser: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let name: String
}

struct AuthSession: Codable, Equatable, Sendable {
    let token: String
    let user: AuthUser
    let expiresAt: Date
}

struct AuthRequest: Codable, Sendable {
    var name: String?
    var email: String
    var password: String
}

struct AppleAuthRequest: Codable, Sendable {
    var identityToken: String
    var authorizationCode: String?
    var userIdentifier: String
    var name: String?
    var email: String?
    var rawNonce: String?
}

struct AppleWebAuthStartRequest: Codable, Sendable {
    var mode: String
}

struct AppleWebAuthStartResponse: Codable, Equatable, Sendable {
    var authorizationURL: URL
    var state: String
}

struct AppleWebAuthSessionRequest: Codable, Sendable {
    var handoffToken: String
}

enum AuthMode: String, CaseIterable, Identifiable, Sendable {
    case signIn = "Sign in"
    case signUp = "Create account"

    var id: String { rawValue }

    var apiValue: String {
        switch self {
        case .signIn:
            "signIn"
        case .signUp:
            "signUp"
        }
    }
}

enum AuthValidation {
    static func message(name: String, email: String, password: String, mode: AuthMode) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.contains("@") || !trimmedEmail.contains(".") {
            return "Enter a valid email address."
        }
        if password.count < 8 {
            return "Use at least 8 characters for your password."
        }
        if mode == .signUp && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter your name."
        }
        return nil
    }
}

enum AppleWebAuthCallback {
    static func handoffToken(from url: URL) -> String? {
        guard url.scheme == "thebrief",
              url.host == "apple-auth",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        return components.queryItems?.first { $0.name == "handoff" }?.value
    }

    static func errorMessage(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        return components.queryItems?.first { $0.name == "error" }?.value
    }
}
