import AuthenticationServices
import XCTest
@testable import SignalDaily

@MainActor
final class AuthStoreTests: XCTestCase {
    func testValidationRequiresEmailPasswordAndNameWhenCreatingAccount() {
        XCTAssertEqual(
            AuthValidation.message(name: "", email: "reader@example.com", password: "quiet-news", mode: .signUp),
            "Enter your name."
        )
        XCTAssertEqual(
            AuthValidation.message(name: "Maya", email: "not-email", password: "quiet-news", mode: .signUp),
            "Enter a valid email address."
        )
        XCTAssertEqual(
            AuthValidation.message(name: "Maya", email: "reader@example.com", password: "short", mode: .signUp),
            "Use at least 8 characters for your password."
        )
    }

    func testSignUpPersistsSessionAndClearsPassword() async {
        let defaults = testDefaults(named: "signup")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        store.switchMode(.signUp)
        store.name = "Maya"
        store.email = "Maya@example.com"
        store.password = "quiet-news"

        await store.submit()

        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(store.session?.user.email, "maya@example.com")
        XCTAssertEqual(store.password, "")
        XCTAssertNotNil(defaults.data(forKey: "auth"))
    }

    func testRestoreRefreshesPersistedSession() async {
        let defaults = testDefaults(named: "restore")
        let seed = AuthSession(
            token: "old-token",
            user: AuthUser(id: "old", email: "old@example.com", name: "Old"),
            expiresAt: Date.now.addingTimeInterval(60)
        )
        defaults.set(try? SignalJSON.encoder.encode(seed), forKey: "auth")

        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        await store.restoreSession()

        XCTAssertEqual(store.session?.token, "old-token")
        XCTAssertEqual(store.session?.user.email, "reader@example.com")
    }

    func testAppleSignInPersistsSession() async {
        let defaults = testDefaults(named: "apple")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")

        await store.signInWithApple(
            identityToken: "apple.identity.token",
            authorizationCode: "auth-code",
            userIdentifier: "apple-user-123",
            name: "Maya Apple",
            email: "maya@privaterelay.appleid.com",
            rawNonce: "raw-nonce"
        )

        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(store.session?.token, "apple-token")
        XCTAssertEqual(store.session?.user.name, "Maya Apple")
        XCTAssertNotNil(defaults.data(forKey: "auth"))
    }

    func testAppleSignInRequiresIdentityToken() async {
        let defaults = testDefaults(named: "apple-empty-token")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")

        await store.signInWithApple(
            identityToken: "",
            authorizationCode: nil,
            userIdentifier: "apple-user-123",
            name: nil,
            email: nil,
            rawNonce: "raw-nonce"
        )

        XCTAssertFalse(store.isSignedIn)
        XCTAssertEqual(store.errorMessage, "Apple did not return a valid identity token.")
    }

    func testPreparingAppleAuthorizationClearsStaleErrors() {
        let defaults = testDefaults(named: "apple-prepare")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        store.errorMessage = "Old Apple error"

        let request = ASAuthorizationAppleIDProvider().createRequest()
        store.prepareAppleAuthorization(request)

        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.appleDiagnosticMessage, "Apple auth diagnostic: native sheet opened.")
        XCTAssertEqual(request.requestedScopes, [.fullName, .email])
        XCTAssertEqual(request.nonce?.count, 64)
        XCTAssertFalse(store.isWorking)
    }

    func testAppleNonceHashMatchesAppleRequestRequirement() {
        XCTAssertEqual(
            AppleSignInNonce.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(AppleSignInNonce.randomString(length: 12).count, 12)
    }

    func testAppleAuthorizationCancelledUsesActionableMessage() {
        let defaults = testDefaults(named: "apple-cancelled")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        let error = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue)

        store.handleAppleAuthorizationFailure(error)

        XCTAssertFalse(store.isWorking)
        XCTAssertEqual(store.appleDiagnosticMessage, "Apple auth diagnostic: canceled (1001)")
        XCTAssertEqual(
            store.errorMessage,
            "Apple sign-in did not finish. Open it again and complete the Apple sheet with Face ID, passcode, or your Apple ID password."
        )
        XCTAssertTrue(store.shouldOfferAppleWebFallback)
    }

    func testAppleAuthorizationUnknownOffersEmailFallback() {
        let defaults = testDefaults(named: "apple-unknown")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        let error = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.unknown.rawValue)

        store.handleAppleAuthorizationFailure(error)

        XCTAssertEqual(
            store.errorMessage,
            "Apple sign-in could not start. Try again, or create an account with email for now."
        )
        XCTAssertTrue(store.shouldOfferAppleWebFallback)
    }

    func testAppleWebAuthorizationStartReturnsURLAndMarksWorking() async {
        let defaults = testDefaults(named: "apple-web-start")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")

        let url = await store.startAppleWebAuthorization()

        XCTAssertEqual(url?.absoluteString, "https://appleid.apple.com/auth/authorize?state=test")
        XCTAssertTrue(store.isWorking)
        XCTAssertEqual(store.appleDiagnosticMessage, "Apple auth diagnostic: browser flow opened.")
    }

    func testAppleWebAuthorizationStartFailureKeepsRetryAvailable() async {
        let defaults = testDefaults(named: "apple-web-start-failure")
        let store = AuthStore(service: FailingAppleWebStartService(), defaults: defaults, sessionKey: "auth")

        let url = await store.startAppleWebAuthorization()

        XCTAssertNil(url)
        XCTAssertFalse(store.isWorking)
        XCTAssertEqual(store.errorMessage, "Apple browser sign-in is not configured yet.")
        XCTAssertEqual(store.appleDiagnosticMessage, "Apple auth diagnostic: browser start failed.")
        XCTAssertTrue(store.shouldOfferAppleWebFallback)
    }

    func testAppleWebAuthorizationCallbackPersistsSession() async {
        let defaults = testDefaults(named: "apple-web-callback")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        let callback = URL(string: "thebrief://apple-auth?handoff=handoff-token")!

        await store.completeAppleWebAuthorization(callbackURL: callback)

        XCTAssertFalse(store.isWorking)
        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(store.session?.token, "apple-web-token")
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(defaults.data(forKey: "auth"))
    }

    func testAppleWebAuthorizationCallbackRequiresHandoffToken() async {
        let defaults = testDefaults(named: "apple-web-missing-handoff")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        let callback = URL(string: "thebrief://apple-auth?error=user_cancelled_authorize")!

        await store.completeAppleWebAuthorization(callbackURL: callback)

        XCTAssertFalse(store.isSignedIn)
        XCTAssertEqual(store.errorMessage, "Apple sign-in was cancelled before it finished.")
        XCTAssertTrue(store.shouldOfferAppleWebFallback)
    }

    #if DEBUG
    func testDeveloperBypassCreatesPersistedDebugSession() {
        let defaults = testDefaults(named: "developer")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        store.password = "temporary"
        store.errorMessage = "Old error"

        store.signInAsDeveloper()

        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(store.session?.token, "debug-developer-session")
        XCTAssertEqual(store.session?.user.email, "dev@thebrief.local")
        XCTAssertEqual(store.password, "")
        XCTAssertNil(store.errorMessage)
        XCTAssertNotNil(defaults.data(forKey: "auth"))
    }
    #endif

    func testSignOutClearsSession() async {
        let defaults = testDefaults(named: "signout")
        let store = AuthStore(service: RecordingAuthService(), defaults: defaults, sessionKey: "auth")
        store.email = "reader@example.com"
        store.password = "quiet-news"
        await store.submit()

        await store.signOut()

        XCTAssertFalse(store.isSignedIn)
        XCTAssertNil(defaults.data(forKey: "auth"))
    }

    private func testDefaults(named name: String) -> UserDefaults {
        let suiteName = "SignalDaily.AuthStoreTests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class RecordingAuthService: AuthServicing, @unchecked Sendable {
    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        makeSession(name: name, email: email, token: "created-token")
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        makeSession(name: "Reader", email: email, token: "signed-in-token")
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        userIdentifier: String,
        name: String?,
        email: String?,
        rawNonce: String?
    ) async throws -> AuthSession {
        makeSession(name: name ?? "Apple Reader", email: email ?? "\(userIdentifier)@privaterelay.appleid.com", token: "apple-token")
    }

    func startAppleWebSignIn(mode: AuthMode) async throws -> AppleWebAuthStartResponse {
        AppleWebAuthStartResponse(
            authorizationURL: URL(string: "https://appleid.apple.com/auth/authorize?state=test")!,
            state: mode.apiValue
        )
    }

    func completeAppleWebSignIn(handoffToken: String) async throws -> AuthSession {
        makeSession(name: "Apple Reader", email: "\(handoffToken)@privaterelay.appleid.com", token: "apple-web-token")
    }

    func session(token: String) async throws -> AuthSession {
        makeSession(name: "Reader", email: "reader@example.com", token: token)
    }

    func signOut(token: String) async throws {}

    private func makeSession(name: String, email: String, token: String) -> AuthSession {
        AuthSession(
            token: token,
            user: AuthUser(
                id: "user_test",
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                name: name
            ),
            expiresAt: Date.now.addingTimeInterval(60 * 60)
        )
    }
}

private final class FailingAppleWebStartService: AuthServicing, @unchecked Sendable {
    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        throw AuthAPIClient.APIError.invalidResponse
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        throw AuthAPIClient.APIError.invalidResponse
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        userIdentifier: String,
        name: String?,
        email: String?,
        rawNonce: String?
    ) async throws -> AuthSession {
        throw AuthAPIClient.APIError.invalidResponse
    }

    func startAppleWebSignIn(mode: AuthMode) async throws -> AppleWebAuthStartResponse {
        throw AuthAPIClient.APIError.server(
            message: "Apple browser sign-in is not configured yet.",
            statusCode: 503
        )
    }

    func completeAppleWebSignIn(handoffToken: String) async throws -> AuthSession {
        throw AuthAPIClient.APIError.invalidResponse
    }

    func session(token: String) async throws -> AuthSession {
        throw AuthAPIClient.APIError.invalidResponse
    }

    func signOut(token: String) async throws {}
}
