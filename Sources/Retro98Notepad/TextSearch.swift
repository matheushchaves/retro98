import Foundation

/// Find and Find Next: the next match from where the selection is, never wrapping around the text.
enum TextSearch {
    /// The next match after the selection (forward) or before it (backward), in UTF-16 units; nil when none.
    static func find(_ needle: String, in text: String, selection: NSRange, forward: Bool, matchCase: Bool) -> NSRange? {
        guard !needle.isEmpty else { return nil }
        let string = text as NSString
        var options: NSString.CompareOptions = matchCase ? [] : [.caseInsensitive]
        if !forward { options.insert(.backwards) }
        let start = min(selection.location + selection.length, string.length)
        let area = forward ? NSRange(location: start, length: string.length - start)
                           : NSRange(location: 0, length: min(selection.location, string.length))
        let found = string.range(of: needle, options: options, range: area)
        return found.location == NSNotFound ? nil : found
    }
}
