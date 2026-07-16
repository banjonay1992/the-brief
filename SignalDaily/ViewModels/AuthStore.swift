import AuthenticationServices
import Foundation

@MainActor
@Observable
final class AuthStore {
    private let service: AuthServicing
    private let defaults: UserDefaults
    private let sessionKey: String
    private var pendingAppleNonce: String?

    private(set) var session: AuthSession?
    var mode: AuthMode = .signIn
    var name = ""
    var email = ""
    var password = ""
    var isWorking = false
    var errorMessage: String?
    var appleDiagnosticMessage: String?
    var shouldOfferAppleWebFallback = false

    var isSignedIn: Bool {
        session != nil
    }

    var userDisplayName: String {
        session?.user.name.isEmpty == false ? session?.user.name ?? "Reader" : "Reader"
    }

    init(
        service: AuthServicing,
        defaults: UserDefaults = .standard,
        sessionKey: String = "SignalDaily.authSession"
    ) {
        self.service = service
        self.defaults = defaults
        self.sessionKey = sessionKey
        self.session = Self.loadSession(defaults: defaults, key: sessionKey)
    }

    func restoreSession() async {
        guard let token = session?.token else { return }
        do {
            session = try await service.session(token: token)
            persistSession()
        } catch {
            clearSession()
        }
    }

    func submit() async {
        errorMessage = AuthValidation.message(name: name, email: email, password: password, mode: mode)
        appleDiagnosticMessage = nil
        guard errorMessage == nil else { return }

        isWorking = true
        defer { isWorking = false }

        do {
            switch mode {
            case .signIn:
                session = try await service.signIn(email: email, password: password)
            case .signUp:
                session = try await service.signUp(name: name, email: email, password: password)
            }
            password = ""
            persistSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        userIdentifier: String,
        name: String?,
        email: String?,
        rawNonce: String? = nil
    ) async {
        guard !identityToken.isEmpty else {
            errorMessage = "Apple did not return a valid identity token."
            appleDiagnosticMessage = "Apple auth diagnostic: missing identity token after native success."
            return
        }

        isWorking = true
        errorMessage = nil
        appleDiagnosticMessage = nil
        defer { isWorking = false }

        do {
            session = try await service.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                userIdentifier: userIdentifier,
                name: name,
                email: email,
                rawNonce: rawNonce
            )
            password = ""
            persistSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAppleWebAuthorization() async -> URL? {
        isWorking = true
        errorMessage = nil
        shouldOfferAppleWebFallback = false
        appleDiagnosticMessage = "Apple auth diagnostic: browser flow starting."

        do {
            let response = try await service.startAppleWebSignIn(mode: mode)
            appleDiagnosticMessage = "Apple auth diagnostic: browser flow opened."
            return response.authorizationURL
        } catch {
            isWorking = false
            errorMessage = error.localizedDescription
            appleDiagnosticMessage = "Apple auth diagnostic: browser start failed."
            shouldOfferAppleWebFallback = true
            return nil
        }
    }

    func completeAppleWebAuthorization(callbackURL: URL) async {
        guard let handoffToken = AppleWebAuthCallback.handoffToken(from: callbackURL) else {
            isWorking = false
            let appleError = AppleWebAuthCallback.errorMessage(from: callbackURL)
            errorMessage = appleError == "user_cancelled_authorize"
                ? "Apple sign-in was cancelled before it finished."
                : "Apple sign-in returned without a valid account handoff. Try again."
            appleDiagnosticMessage = "Apple auth diagnostic: browser callback missing handoff."
            shouldOfferAppleWebFallback = true
            return
        }

        do {
            session = try await service.completeAppleWebSignIn(handoffToken: handoffToken)
            password = ""
            errorMessage = nil
            appleDiagnosticMessage = nil
            shouldOfferAppleWebFallback = false
            persistSession()
        } catch {
            errorMessage = error.localizedDescription
            appleDiagnosticMessage = "Apple auth diagnostic: browser handoff failed."
            shouldOfferAppleWebFallback = true
        }
        isWorking = false
    }

    func handleAppleWebAuthorizationFailure(_ error: Error?) {
        isWorking = false
        shouldOfferAppleWebFallback = true
        if let error {
            errorMessage = error.localizedDescription
            appleDiagnosticMessage = "Apple auth diagnostic: browser flow failed."
        } else {
            errorMessage = "Apple sign-in could not open. Try again, or use email for now."
            appleDiagnosticMessage = "Apple auth diagnostic: browser flow could not start."
        }
    }

    func prepareAppleAuthorization(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInNonce.randomString()
        pendingAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
        errorMessage = nil
        shouldOfferAppleWebFallback = false
        appleDiagnosticMessage = "Apple auth diagnostic: native sheet opened."
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = pendingAppleNonce
            else {
                handleAppleAuthorizationFailure(AppleAuthorizationFlowError.missingIdentityToken)
                pendingAppleNonce = nil
                return
            }

            let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let name = credential.fullName.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .medium)
            }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            await signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                userIdentifier: credential.user,
                name: name.isEmpty ? nil : name,
                email: credential.email,
                rawNonce: nonce
            )
            pendingAppleNonce = nil
        } catch {
            handleAppleAuthorizationFailure(error)
            pendingAppleNonce = nil
        }
    }

    func handleAppleAuthorizationFailure(_ error: Error) {
        isWorking = false
        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain,
              let code = ASAuthorizationError.Code(rawValue: nsError.code)
        else {
            errorMessage = error.localizedDescription
            appleDiagnosticMessage = "Apple auth diagnostic: \(nsError.domain) \(nsError.code)"
            return
        }

        appleDiagnosticMessage = "Apple auth diagnostic: \(code.debugLabel) (\(nsError.code))"
        switch code {
        case .canceled:
            errorMessage = "Apple sign-in did not finish. Open it again and complete the Apple sheet with Face ID, passcode, or your Apple ID password."
            shouldOfferAppleWebFallback = true
        case .failed:
            errorMessage = "Apple sign-in failed before it reached The Brief. Check your Apple ID is signed in on this device, then try again."
            shouldOfferAppleWebFallback = true
        case .invalidResponse:
            errorMessage = "Apple returned an unreadable sign-in response. Try again in a moment."
            shouldOfferAppleWebFallback = true
        case .notHandled:
            errorMessage = "Apple could not handle the sign-in request on this device. Check your Apple ID settings and try again."
            shouldOfferAppleWebFallback = true
        case .unknown:
            errorMessage = "Apple sign-in could not start. Try again, or create an account with email for now."
            shouldOfferAppleWebFallback = true
        default:
            errorMessage = "Apple sign-in could not finish. Try again, or create an account with email for now."
            shouldOfferAppleWebFallback = true
        }
    }

    #if DEBUG
    func signInAsDeveloper() {
        session = AuthSession(
            token: "debug-developer-session",
            user: AuthUser(
                id: "user_debug",
                email: "dev@thebrief.local",
                name: "Developer"
            ),
            expiresAt: Date.now.addingTimeInterval(60 * 60 * 24 * 30)
        )
        errorMessage = nil
        password = ""
        persistSession()
    }
    #endif

    func signOut() async {
        let token = session?.token
        clearSession()
        if let token {
            try? await service.signOut(token: token)
        }
    }

    func switchMode(_ newMode: AuthMode) {
        mode = newMode
        errorMessage = nil
        appleDiagnosticMessage = nil
        shouldOfferAppleWebFallback = false
    }

    private func persistSession() {
        guard let session else {
            clearSession()
            return
        }
        if let data = try? SignalJSON.encoder.encode(session) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private func clearSession() {
        session = nil
        defaults.removeObject(forKey: sessionKey)
    }

    private static func loadSession(defaults: UserDefaults, key: String) -> AuthSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? SignalJSON.decoder.decode(AuthSession.self, from: data)
    }
}

enum AppleAuthorizationFlowError: LocalizedError {
    case missingIdentityToken

    var errorDescription: String? {
        "Apple did not return a valid identity token."
    }
}

private extension ASAuthorizationError.Code {
    var debugLabel: String {
        switch self {
        case .canceled:
            "canceled"
        case .failed:
            "failed"
        case .invalidResponse:
            "invalidResponse"
        case .notHandled:
            "notHandled"
        case .unknown:
            "unknown"
        default:
            "code"
        }
    }
}
