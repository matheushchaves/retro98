import Foundation
import Retro98Settings

/// The "time remaining" line of the progress dialog.
public enum ProgressEstimate {
    static let warmUp: TimeInterval = 2

    /// nil until there is enough to go on (2 s and some progress).
    public static func remaining(completed: Int64, total: Int64, elapsed: TimeInterval) -> TimeInterval? {
        guard elapsed >= warmUp, completed > 0, total >= completed else { return nil }
        return Double(total - completed) * elapsed / Double(completed)
    }

    /// Seconds under a minute, minutes after that, both rounded up.
    public static func text(_ remaining: TimeInterval?, languages: [String]) -> String {
        guard let remaining else {
            return LocalizedText(en: "Calculating the time remaining...", ptBR: "Calculando o tempo restante...").resolve(for: languages)
        }
        if remaining < 60 {
            let seconds = max(1, Int(remaining.rounded(.up)))
            return seconds == 1
                ? LocalizedText(en: "1 second remaining", ptBR: "1 segundo restante").resolve(for: languages)
                : LocalizedText(en: "\(seconds) seconds remaining", ptBR: "\(seconds) segundos restantes").resolve(for: languages)
        }
        let minutes = Int((remaining / 60).rounded(.up))
        return LocalizedText(en: "\(minutes) minutes remaining", ptBR: "\(minutes) minutos restantes").resolve(for: languages)
    }
}
