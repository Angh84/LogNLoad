import XCTest

/// The base of every flow in Flows/: the app under test and screenshots for checking a screen.
@MainActor
class Harness: XCTestCase {
    let app = XCUIApplication()

    /// Saves the screen to `<SHOTS>/<name>.png`, where `SHOTS` reaches the runner as `TEST_RUNNER_SHOTS`.
    func shot(_ name: String) {
        sleep(1)
        let directory = ProcessInfo.processInfo.environment["SHOTS"] ?? NSTemporaryDirectory()
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: directory).appending(path: "\(name).png"))
    }
}
