import Testing
@testable import LogNLoad

struct TrimmedTextTests {
    @Test func leadingAndTrailingWhitespaceAndNewlinesAreTrimmed() {
        #expect(trimmed("  Push day \n") == "Push day")
        #expect(trimmed("\n\tSeat 4\n") == "Seat 4")
    }

    @Test func innerSpacingIsKeptAsTyped() {
        #expect(trimmed(" Seat 4,  pin 7\nhandles low ") == "Seat 4,  pin 7\nhandles low")
    }

    @Test func emptyAfterTrimmingIsNoValue() {
        #expect(trimmed("") == nil)
        #expect(trimmed("  \n\t ") == nil)
        #expect(trimmed(nil) == nil)
    }
}
