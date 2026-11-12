import Foundation
import Testing
@testable import Retro98FilesCore

@Test func remainingTimeTexts() {
    #expect(ProgressEstimate.remaining(completed: 50, total: 100, elapsed: 10) == 10)
    #expect(ProgressEstimate.remaining(completed: 50, total: 100, elapsed: 1) == nil)
    #expect(ProgressEstimate.remaining(completed: 0, total: 100, elapsed: 10) == nil)
    #expect(ProgressEstimate.text(10, languages: ["pt-BR"]) == "10 segundos restantes")
    #expect(ProgressEstimate.text(9.2, languages: ["pt-BR"]) == "10 segundos restantes")
    #expect(ProgressEstimate.text(61, languages: ["pt-BR"]) == "2 minutos restantes")
    #expect(ProgressEstimate.text(0.4, languages: ["pt-BR"]) == "1 segundo restante")
    #expect(ProgressEstimate.text(nil, languages: ["pt-BR"]) == "Calculando o tempo restante...")
    #expect(ProgressEstimate.text(10, languages: ["en"]) == "10 seconds remaining")
    #expect(ProgressEstimate.text(nil, languages: ["en"]) == "Calculating the time remaining...")
}
