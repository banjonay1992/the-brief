import XCTest

final class AppIconAssetTests: XCTestCase {
    func testOfficialAppIconAssetIsConfiguredForTestFlightBuilds() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .path(percentEncoded: false)
        let appIconSet = URL(fileURLWithPath: projectRoot)
            .appending(path: "SignalDaily/Assets.xcassets/AppIcon.appiconset")
        let contentsURL = appIconSet.appending(path: "Contents.json")
        let imageURL = appIconSet.appending(path: "TheBriefAppIcon.png")

        let contents = try Data(contentsOf: contentsURL)
        let icon = try JSONDecoder().decode(AppIconContents.self, from: contents)

        XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path(percentEncoded: false)))
        XCTAssertEqual(icon.images.first?.filename, "TheBriefAppIcon.png")
        XCTAssertEqual(icon.images.first?.size, "1024x1024")
        XCTAssertEqual(icon.images.first?.idiom, "universal")
    }
}

private struct AppIconContents: Decodable {
    let images: [AppIconImage]
}

private struct AppIconImage: Decodable {
    let filename: String
    let idiom: String
    let size: String
}
