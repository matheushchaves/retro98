/// Word wrapping for pixel text.
public enum RetroText {
    /// Wraps at spaces so each line fits `maxWidth` (a single overlong word gets its own line);
    /// explicit line breaks are kept.
    public static func wrap(_ text: String, maxWidth: Int, font: PixelFont = .regular) -> [String] {
        text.components(separatedBy: "\n").flatMap { paragraph -> [String] in
            var lines: [String] = []
            var current = ""
            for word in paragraph.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
                let candidate = current.isEmpty ? word : current + " " + word
                if PixelText.width(of: candidate, font: font) <= maxWidth || current.isEmpty {
                    current = candidate
                } else {
                    lines.append(current)
                    current = word
                }
            }
            return lines + [current]
        }
    }

    /// The whole text if it fits, else the longest prefix plus "…" that fits ("" if not even "…" fits).
    public static func fit(_ text: String, maxWidth: Int, font: PixelFont = .regular) -> String {
        guard PixelText.width(of: text, font: font) > maxWidth else { return text }
        for length in stride(from: text.count - 1, through: 0, by: -1) {
            let candidate = String(text.prefix(length)).trimmingCharacters(in: .whitespaces) + "…"
            if PixelText.width(of: candidate, font: font) <= maxWidth { return candidate }
        }
        return ""
    }
}
