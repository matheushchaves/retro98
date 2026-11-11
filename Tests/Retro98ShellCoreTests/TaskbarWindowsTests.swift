import CoreGraphics
import Foundation
import Testing
@testable import Retro98ShellCore

func snap(_ id: Int, focused: Bool = false, minimized: Bool = false) -> WindowSnapshot<Int> {
    WindowSnapshot(id: id, title: "Janela \(id)", appName: "App", appURL: nil, isMinimized: minimized, isFocused: focused)
}

@Test func knownWindowsKeepTheirOrderAndNewOnesGoLast() {
    #expect(TaskbarOrdering.order(previous: [1, 2], current: [snap(3), snap(1), snap(2)]).map(\.id) == [1, 2, 3])
}

@Test func closedWindowsDisappearFromTheOrder() {
    #expect(TaskbarOrdering.order(previous: [1, 2, 3], current: [snap(3), snap(1)]).map(\.id) == [1, 3])
}

@Test func buttonsUseMaxWidthWhenThereIsRoom() {
    let frames = TaskButtonLayout.frames(count: 2, area: CGRect(x: 100, y: 7, width: 1000, height: 22))
    #expect(frames == [CGRect(x: 100, y: 7, width: 160, height: 22), CGRect(x: 263, y: 7, width: 160, height: 22)])
}

@Test func buttonsShareTheAreaWhenCrowded() {
    let frames = TaskButtonLayout.frames(count: 5, area: CGRect(x: 0, y: 0, width: 512, height: 22))
    #expect(frames.allSatisfy { $0?.width == 100 })     // (512 - 4×3) / 5 = 100
    #expect(frames.last??.maxX == 512)
}

@Test func buttonsShrinkToMinimumAndOverflowIsHidden() {
    let frames = TaskButtonLayout.frames(count: 30, area: CGRect(x: 0, y: 0, width: 430, height: 22))
    #expect(frames.compactMap { $0 }.count == 10)       // 10×40 + 9×3 = 427 ≤ 430
    #expect(frames.compactMap { $0 }.allSatisfy { $0.width == 40 && $0.maxX <= 430 })
    #expect(frames[10] == nil)
}

@Test func noButtonsWhenThereIsNoRoom() {
    #expect(TaskButtonLayout.frames(count: 3, area: CGRect(x: 0, y: 0, width: 20, height: 22)) == [nil, nil, nil])
    #expect(TaskButtonLayout.frames(count: 0, area: CGRect(x: 0, y: 0, width: 500, height: 22)).isEmpty)
}

@Test func titleFitsWithEllipsis() {
    let measure = { (text: String) in text.count * 6 }
    #expect(TitleFitting.fit("Relatório", maxWidth: 100, measure: measure) == "Relatório")
    #expect(TitleFitting.fit("Relatório anual de vendas", maxWidth: 60, measure: measure) == "Relatório…")
    #expect(TitleFitting.fit("Qualquer", maxWidth: 4, measure: measure) == "")
}

@Test func clickingTheActiveWindowMinimizesIt() {
    #expect(TaskButtonClick.action(isFocused: true, isMinimized: false) == .minimize)
    #expect(TaskButtonClick.action(isFocused: false, isMinimized: false) == .activate)
    #expect(TaskButtonClick.action(isFocused: true, isMinimized: true) == .activate)
}

@Test func menuTexts() {
    #expect([TaskButtonMenuText.restore(["pt-BR"]), TaskButtonMenuText.minimize(["pt-BR"]), TaskButtonMenuText.close(["pt-BR"])]
            == ["Restaurar", "Minimizar", "Fechar"])
    #expect([TaskButtonMenuText.restore(["en"]), TaskButtonMenuText.minimize(["en"]), TaskButtonMenuText.close(["en"])]
            == ["Restore", "Minimize", "Close"])
}
