import AppKit
import Testing
@testable import Retro98UI

@Test func progressBlocksFillProportionally() {
    #expect(RetroProgressBar.blockCount(fraction: 0, width: 336) == 0)
    #expect(RetroProgressBar.blockCount(fraction: 1, width: 336) == 33)
    #expect(RetroProgressBar.blockCount(fraction: 0.5, width: 336) == 16)
    #expect(RetroProgressBar.blockCount(fraction: 2, width: 336) == 33)
    #expect(RetroProgressBar.blockCount(fraction: -1, width: 336) == 0)
}

@MainActor @Test func progressBarDrawsNavyBlocks() {
    let bar = RetroProgressBar(frame: CGRect(x: 0, y: 0, width: 336, height: 18))
    bar.fraction = 0.5
    let image = renderView(bar)
    #expect(image.color(x: 4, y: 9) == Palette.selection)
    #expect(image.color(x: 300, y: 9) != Palette.selection)
}

@Test func animationPageArcs() {
    let width: CGFloat = 336
    let origins = (0..<FileOperationAnimation.frameCount).map { FileOperationAnimation.pageOrigin(frame: $0, width: width) }
    #expect(origins.count == 8)
    #expect(zip(origins, origins.dropFirst()).allSatisfy { $0.x < $1.x })
    let highest = origins.map(\.y).min()
    #expect(origins[3].y == highest && origins[4].y == highest)
    #expect(origins[0].x >= 0 && origins[0].x + 16 <= 32)
    #expect(origins[7].x >= width - 32 && origins[7].x + 16 <= width)
}

@MainActor @Test func dialogCancelCallsBack() {
    let dialog = RetroProgressDialog(title: "Copiando...", style: .folderToFolder, cancelTitle: "Cancelar")
    var cancelled = 0
    dialog.onCancel = { cancelled += 1 }
    dialog.window.cancelOperation(nil)
    #expect(cancelled == 1)
    #expect(dialog.window.level == .normal)
    #expect(dialog.window.contentContainer.bounds.size == CGSize(width: 360, height: 176))
}

@Test func messageBoxFitsFourButtons() {
    let buttons = ["Sim", "Sim para todos", "Não", "Cancelar"]
    let layout = RetroMessageBox.layout(message: "Substituir?", buttons: buttons)
    let needed = buttons.map { RetroButton.preferredSize(title: $0, icon: nil, bold: false).width }.reduce(0, +) + 6 * 3 + 12 * 2
    #expect(layout.contentSize.width >= needed)
}

@Test func messageBoxKeepsBlankLines() {
    #expect(RetroMessageBox.layout(message: "a\n\nb", buttons: ["OK"]).lines == ["a", "", "b"])
}
