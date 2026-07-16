import XCTest
@testable import SignalDaily

final class AuthAPIClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testAuthClientSurfacesServerErrorMessages() async throws {
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/apple")
            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            ))
            return (response, Data(#"{"error":"Apple sign-in could not be verified."}"#.utf8))
        }

        let client = AuthAPIClient(baseURL: URL(string: "https://example.com")!, session: stubSession())

        do {
            _ = try await client.signInWithApple(
                identityToken: "bad-token",
                authorizationCode: nil,
                userIdentifier: "apple-user-123",
                name: nil,
                email: nil,
                rawNonce: nil
            )
            XCTFail("Expected Apple sign-in to surface the backend error.")
        } catch let error as AuthAPIClient.APIError {
            XCTAssertEqual(error, .server(message: "Apple sign-in could not be verified.", statusCode: 401))
            XCTAssertEqual(error.localizedDescription, "Apple sign-in could not be verified.")
        }
    }

    func testAuthClientSendsApplePayloadAndDecodesSession() async throws {
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/apple")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try requestBodyData(request)
            let payload = try SignalJSON.decoder.decode(AppleAuthRequest.self, from: body)
            XCTAssertEqual(payload.userIdentifier, "apple-user-123")
            XCTAssertEqual(payload.email, "reader@privaterelay.appleid.com")
            XCTAssertEqual(payload.rawNonce, "raw-nonce")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            ))
            let session = AuthSession(
                token: "session-token",
                user: AuthUser(id: "apple_123", email: "reader@privaterelay.appleid.com", name: "Reader"),
                expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
            return (response, try SignalJSON.encoder.encode(session))
        }

        let client = AuthAPIClient(baseURL: URL(string: "https://example.com")!, session: stubSession())
        let session = try await client.signInWithApple(
            identityToken: "identity-token",
            authorizationCode: "auth-code",
            userIdentifier: "apple-user-123",
            name: "Reader",
            email: "reader@privaterelay.appleid.com",
            rawNonce: "raw-nonce"
        )

        XCTAssertEqual(session.token, "session-token")
        XCTAssertEqual(session.user.email, "reader@privaterelay.appleid.com")
    }

    func testAuthClientStartsAppleBrowserFlow() async throws {
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/apple/web/start")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try requestBodyData(request)
            let payload = try SignalJSON.decoder.decode(AppleWebAuthStartRequest.self, from: body)
            XCTAssertEqual(payload.mode, "signUp")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            ))
            return (response, Data(#"{"authorizationURL":"https://appleid.apple.com/auth/authorize?state=test","state":"test"}"#.utf8))
        }

        let client = AuthAPIClient(baseURL: URL(string: "https://example.com")!, session: stubSession())
        let response = try await client.startAppleWebSignIn(mode: .signUp)

        XCTAssertEqual(response.authorizationURL.host(), "appleid.apple.com")
        XCTAssertEqual(response.state, "test")
    }

    func testAuthClientCompletesAppleBrowserHandoff() async throws {
        StubURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/auth/apple/web/session")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try requestBodyData(request)
            let payload = try SignalJSON.decoder.decode(AppleWebAuthSessionRequest.self, from: body)
            XCTAssertEqual(payload.handoffToken, "handoff-token")

            let response = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["content-type": "application/json"]
            ))
            let session = AuthSession(
                token: "web-session-token",
                user: AuthUser(id: "apple_web", email: "reader@privaterelay.appleid.com", name: "Reader"),
                expiresAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
            return (response, try SignalJSON.encoder.encode(session))
        }

        let client = AuthAPIClient(baseURL: URL(string: "https://example.com")!, session: stubSession())
        let session = try await client.completeAppleWebSignIn(handoffToken: "handoff-token")

        XCTAssertEqual(session.token, "web-session-token")
        XCTAssertEqual(session.user.email, "reader@privaterelay.appleid.com")
    }

    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func requestBodyData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let bodyStream = request.httpBodyStream else {
        throw XCTSkip("Expected a JSON request body.")
    }

    bodyStream.open()
    defer { bodyStream.close() }

    let bufferSize = 1_024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    var data = Data()
    while bodyStream.hasBytesAvailable {
        let count = bodyStream.read(&buffer, maxLength: bufferSize)
        if count < 0 {
            throw AuthAPIClient.APIError.invalidResponse
        }
        if count == 0 {
            break
        }
        data.append(buffer, count: count)
    }
    return data
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: AuthAPIClient.APIError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
