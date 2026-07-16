import Foundation

protocol AuthServicing: Sendable {
    func signUp(name: String, email: String, password: String) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthSession
    func signInWithApple(identityToken: String, authorizationCode: String?, userIdentifier: String, name: String?, email: String?, rawNonce: String?) async throws -> AuthSession
    func startAppleWebSignIn(mode: AuthMode) async throws -> AppleWebAuthStartResponse
    func completeAppleWebSignIn(handoffToken: String) async throws -> AuthSession
    func session(token: String) async throws -> AuthSession
    func signOut(token: String) async throws
}

struct AuthAPIClient: AuthServicing {
    enum APIError: Error, LocalizedError, Equatable {
        case server(message: String, statusCode: Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .server(let message, _):
                message
            case .invalidResponse:
                "The account service returned an unreadable response."
            }
        }
    }

    private struct APIErrorResponse: Decodable {
        let error: String
    }

    private struct EmptyRequest: Encodable {}

    private struct EmptyResponse: Decodable {
        init() {}
    }

    let baseURL: URL
    let session: URLSession
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = SignalJSON.decoder
        self.encoder = SignalJSON.encoder
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        try await request(
            "/api/auth/signup",
            method: "POST",
            body: AuthRequest(name: name, email: email, password: password),
            token: nil
        )
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        try await request(
            "/api/auth/signin",
            method: "POST",
            body: AuthRequest(name: nil, email: email, password: password),
            token: nil
        )
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        userIdentifier: String,
        name: String?,
        email: String?,
        rawNonce: String?
    ) async throws -> AuthSession {
        try await request(
            "/api/auth/apple",
            method: "POST",
            body: AppleAuthRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                userIdentifier: userIdentifier,
                name: name,
                email: email,
                rawNonce: rawNonce
            ),
            token: nil
        )
    }

    func startAppleWebSignIn(mode: AuthMode) async throws -> AppleWebAuthStartResponse {
        try await request(
            "/api/auth/apple/web/start",
            method: "POST",
            body: AppleWebAuthStartRequest(mode: mode.apiValue),
            token: nil
        )
    }

    func completeAppleWebSignIn(handoffToken: String) async throws -> AuthSession {
        try await request(
            "/api/auth/apple/web/session",
            method: "POST",
            body: AppleWebAuthSessionRequest(handoffToken: handoffToken),
            token: nil
        )
    }

    func session(token: String) async throws -> AuthSession {
        try await request(
            "/api/auth/session",
            method: "GET",
            body: Optional<EmptyRequest>.none,
            token: token
        )
    }

    func signOut(token: String) async throws {
        _ = try await request(
            "/api/auth/signout",
            method: "POST",
            body: Optional<EmptyRequest>.none,
            token: token
        ) as EmptyResponse
    }

    func endpointURL(_ path: String) -> URL {
        let trimmedBase = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedBase)/\(trimmedPath)") ?? baseURL
    }

    private func request<T: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        body: Body?,
        token: String?
    ) async throws -> T {
        var request = URLRequest(url: endpointURL(path))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw APIError.server(message: errorResponse.error, statusCode: httpResponse.statusCode)
            }
            throw APIError.invalidResponse
        }
        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }
}

struct MockAuthService: AuthServicing {
    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        mockSession(name: name, email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        mockSession(name: "Reader", email: email)
    }

    func signInWithApple(
        identityToken: String,
        authorizationCode: String?,
        userIdentifier: String,
        name: String?,
        email: String?,
        rawNonce: String?
    ) async throws -> AuthSession {
        mockSession(name: name ?? "Apple Reader", email: email ?? "\(userIdentifier)@privaterelay.appleid.com")
    }

    func startAppleWebSignIn(mode: AuthMode) async throws -> AppleWebAuthStartResponse {
        AppleWebAuthStartResponse(
            authorizationURL: URL(string: "https://appleid.apple.com/auth/authorize?state=mock")!,
            state: mode.apiValue
        )
    }

    func completeAppleWebSignIn(handoffToken: String) async throws -> AuthSession {
        mockSession(name: "Apple Reader", email: "reader@privaterelay.appleid.com")
    }

    func session(token: String) async throws -> AuthSession {
        AuthSession(
            token: token,
            user: AuthUser(id: "user_mock", email: "reader@example.com", name: "Reader"),
            expiresAt: Date.now.addingTimeInterval(60 * 60 * 24 * 30)
        )
    }

    func signOut(token: String) async throws {}

    private func mockSession(name: String, email: String) -> AuthSession {
        AuthSession(
            token: "mock-session-token",
            user: AuthUser(
                id: "user_mock",
                email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Reader" : name
            ),
            expiresAt: Date.now.addingTimeInterval(60 * 60 * 24 * 30)
        )
    }
}
