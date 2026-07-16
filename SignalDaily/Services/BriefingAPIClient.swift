import Foundation

protocol BriefingServing: Sendable {
    func todayBriefing() async throws -> Briefing
    func briefing(date: String) async throws -> Briefing
    func todayUpdates() async throws -> BriefingUpdates
    func article(id: String) async throws -> StoryDetail
    func source(id: String) async throws -> Source
    func savePreferences(_ preferences: UserPreferences) async throws
    func preferences() async throws -> UserPreferences
    func useDepthToken() async throws -> DepthTokenStatus
    func depthTokensToday() async throws -> DepthTokenStatus
}

struct BriefingAPIClient: BriefingServing {
    enum APIError: Error, LocalizedError {
        case invalidResponse

        var errorDescription: String? {
            "The briefing service returned an unreadable response."
        }
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

    func todayBriefing() async throws -> Briefing {
        try await get("/api/briefings/today")
    }

    func briefing(date: String) async throws -> Briefing {
        try await get("/api/briefings/\(date)")
    }

    func todayUpdates() async throws -> BriefingUpdates {
        try await get("/api/briefings/today/updates")
    }

    func article(id: String) async throws -> StoryDetail {
        try await get("/api/articles/\(id)")
    }

    func source(id: String) async throws -> Source {
        try await get("/api/sources/\(id)")
    }

    func savePreferences(_ preferences: UserPreferences) async throws {
        _ = try await request("/api/users/preferences", method: "POST", body: preferences) as EmptyResponse
    }

    func preferences() async throws -> UserPreferences {
        try await get("/api/users/preferences")
    }

    func useDepthToken() async throws -> DepthTokenStatus {
        try await request("/api/depth-tokens/use", method: "POST", body: EmptyRequest())
    }

    func depthTokensToday() async throws -> DepthTokenStatus {
        try await get("/api/depth-tokens/today")
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        try await request(path, method: "GET", body: Optional<EmptyRequest>.none)
    }

    private func request<T: Decodable, Body: Encodable>(_ path: String, method: String, body: Body?) async throws -> T {
        var request = URLRequest(url: endpointURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        if data.isEmpty, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    func endpointURL(_ path: String) -> URL {
        let trimmedBase = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedBase)/\(trimmedPath)") ?? baseURL
    }
}

struct EmptyRequest: Codable {}
struct EmptyResponse: Codable {}

enum SignalJSON {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
