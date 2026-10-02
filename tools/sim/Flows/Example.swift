import XCTest

/// A template flow. Write each check as its own file beside this one; only this file is committed.
final class ExampleFlow: Harness {
    func testStartWorkout() {
        app.launch()
        app.buttons["Start Workout"].tap()
        shot("picker")
    }
}
