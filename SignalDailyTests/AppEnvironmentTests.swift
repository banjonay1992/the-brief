import XCTest
@testable import SignalDaily

final class AppEnvironmentTests: XCTestCase {
    func testMockEnvironmentBuildsMockService() {
        let environment = AppEnvironment(mode: .mock)

        XCTAssertTrue(environment.briefingService is MockBriefingService)
        XCTAssertTrue(environment.authService is MockAuthService)
    }

    func testAPIEnvironmentBuildsAPIClient() {
        let environment = AppEnvironment(mode: .api(URL(string: "http://127.0.0.1:8787")!))

        XCTAssertTrue(environment.briefingService is BriefingAPIClient)
        XCTAssertTrue(environment.authService is AuthAPIClient)
    }

    func testBuildSettingBooleansCanBeReadFromInfoPlistStrings() {
        XCTAssertTrue(AppEnvironment.boolValue("YES", default: false))
        XCTAssertFalse(AppEnvironment.boolValue("NO", default: true))
    }

    func testReleaseInfoPlistDeclaresSupportedOrientations() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SignalDaily/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        XCTAssertEqual(plist["UISupportedInterfaceOrientations"] as? [String], [
            "UIInterfaceOrientationPortrait"
        ])
        XCTAssertEqual(plist["UISupportedInterfaceOrientations~ipad"] as? [String], [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown",
            "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight"
        ])
    }

    func testAPIClientBuildsNestedEndpointURLs() {
        let client = BriefingAPIClient(baseURL: URL(string: "https://example.com")!)

        XCTAssertEqual(
            client.endpointURL("/api/articles/story_001").absoluteString,
            "https://example.com/api/articles/story_001"
        )
    }

    func testAPIClientBuildsTodayUpdatesEndpointURL() {
        let client = BriefingAPIClient(baseURL: URL(string: "https://example.com")!)

        XCTAssertEqual(
            client.endpointURL("/api/briefings/today/updates").absoluteString,
            "https://example.com/api/briefings/today/updates"
        )
    }

    func testAuthAPIClientBuildsSessionEndpointURL() {
        let client = AuthAPIClient(baseURL: URL(string: "https://example.com")!)

        XCTAssertEqual(
            client.endpointURL("/api/auth/session").absoluteString,
            "https://example.com/api/auth/session"
        )
    }
}
