import Foundation

/// How names and notes are stored: trimmed at both ends, and no value when nothing is left.
func trimmed(_ text: String?) -> String? {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
    return text
}
