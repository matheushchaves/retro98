import AppKit
import Testing
@testable import Retro98UI

@MainActor private final class FakeSource: RetroIconGridDataSource {
    let count: Int
    init(count: Int) { self.count = count }
    func numberOfItems(in grid: RetroIconGrid) -> Int { count }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { "item \(index)" }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { FileIcons.icon(.document, size: 32) }
}

/// A grid in an offscreen window, so it can take focus and host the rename field.
@MainActor private struct GridHarness {
    let grid = RetroIconGrid()
    let source: FakeSource
    let window: NSWindow

    init(count: Int = 10) {
        source = FakeSource(count: count)
        grid.dataSource = source
        let scroll = RetroScroller.makeScrollView(document: grid)
        scroll.frame = CGRect(x: 0, y: 0, width: 450, height: 300)
        window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = scroll
        grid.reloadData()
        window.makeFirstResponder(grid)
    }

    func key(_ code: UInt16, _ characters: String) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)!
    }

    func rightClick(at point: CGPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .rightMouseDown, location: grid.convert(point, to: nil), modifierFlags: [], timestamp: 0,
                           windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    func center(of index: Int) -> CGPoint {
        let cell = IconGridLayout.frame(of: index, columns: IconGridLayout.columns(forWidth: grid.bounds.width))
        return CGPoint(x: cell.midX, y: cell.minY + 20)
    }
}

@MainActor @Test func enterAndF2AskToRename() {
    let harness = GridHarness()
    var renamed: [Int] = []
    harness.grid.onRename = { renamed.append($0) }
    harness.grid.setSelection([2])
    harness.grid.keyDown(with: harness.key(36, "\r"))
    harness.grid.keyDown(with: harness.key(120, String(UnicodeScalar(NSF2FunctionKey)!)))
    #expect(renamed == [2, 2])
}

@MainActor @Test func enterNoLongerOpens() {
    let harness = GridHarness()
    var opened: [Int] = []
    harness.grid.onOpen = { opened.append($0) }
    harness.grid.setSelection([2])
    harness.grid.keyDown(with: harness.key(36, "\r"))
    #expect(opened.isEmpty)
}

@MainActor @Test func editingCommitsAndCancels() throws {
    let harness = GridHarness()
    var ended: [(Int, String?)] = []
    harness.grid.onEndEditing = { ended.append(($0, $1)) }

    harness.grid.beginEditing(at: 1, text: "foto.jpg", selecting: NSRange(location: 0, length: 4))
    let field = try #require(harness.grid.editor)
    #expect(field.stringValue == "foto.jpg")
    #expect((field.currentEditor() as? NSTextView)?.selectedRange() == NSRange(location: 0, length: 4))
    #expect(harness.grid.editingIndex == 1)
    field.stringValue = "novo"
    harness.grid.endEditing(commit: true)
    #expect(ended.count == 1 && ended[0].0 == 1 && ended[0].1 == "novo")
    #expect(harness.grid.editingIndex == nil)
    #expect(field.superview == nil)
    #expect(harness.window.firstResponder === harness.grid)

    harness.grid.beginEditing(at: 1, text: "foto.jpg", selecting: NSRange(location: 0, length: 4))
    let second = try #require(harness.grid.editor)
    let textView = try #require(second.currentEditor() as? NSTextView)
    _ = harness.grid.control(second, textView: textView, doCommandBy: #selector(NSResponder.cancelOperation(_:)))
    #expect(ended.count == 2 && ended[1].0 == 1 && ended[1].1 == nil)
}

@MainActor @Test func moveEditingFollowsTheItem() throws {
    let harness = GridHarness()
    var ended: [(Int, String?)] = []
    harness.grid.onEndEditing = { ended.append(($0, $1)) }
    harness.grid.beginEditing(at: 0, text: "abc", selecting: NSRange(location: 0, length: 3))
    let field = try #require(harness.grid.editor)
    field.stringValue = "abcd"
    harness.grid.moveEditing(to: 3)
    #expect(harness.grid.editingIndex == 3)
    #expect(field.frame.midX.rounded() == harness.center(of: 3).x.rounded())
    #expect(field.stringValue == "abcd")
    #expect(ended.isEmpty)
    harness.grid.moveEditing(to: nil)
    #expect(ended.count == 1 && ended[0].0 == 3 && ended[0].1 == nil)
}

@MainActor @Test func rightClickSelectsTheItemUnderThePointer() {
    let harness = GridHarness()
    var menus: [Int?] = []
    harness.grid.onContextMenu = { index, _ in menus.append(index) }
    harness.grid.setSelection([0])
    harness.grid.rightMouseDown(with: harness.rightClick(at: harness.center(of: 2)))
    #expect(harness.grid.selection == [2])
    #expect(menus == [2])
}

@MainActor @Test func rightClickKeepsAMultipleSelection() {
    let harness = GridHarness()
    var menus: [Int?] = []
    harness.grid.onContextMenu = { index, _ in menus.append(index) }
    harness.grid.setSelection([1, 2])
    harness.grid.rightMouseDown(with: harness.rightClick(at: harness.center(of: 2)))
    #expect(harness.grid.selection == [1, 2])
    harness.grid.rightMouseDown(with: harness.rightClick(at: CGPoint(x: 440, y: 290)))
    #expect(harness.grid.selection.isEmpty)
    #expect(menus == [2, nil])
}

@Test func clickOnASelectedGroupNarrowsOnMouseUp() {
    #expect(IconGridClick.mouseDown(on: 2, selection: [1, 2], extend: false) == ([1, 2], true))
    #expect(IconGridClick.mouseDown(on: 5, selection: [1, 2], extend: false) == ([5], false))
    #expect(IconGridClick.mouseDown(on: 2, selection: [2], extend: false) == ([2], false))
    #expect(IconGridClick.mouseDown(on: 2, selection: [1, 2], extend: true) == ([1], false))
    #expect(IconGridClick.mouseDown(on: 3, selection: [1, 2], extend: true) == ([1, 2, 3], false))
}

@MainActor @Test func dimmedIconsAreGhosted() {
    let red = PixelColor(red: 255, green: 0, blue: 0)
    let icon = PixelIcon(width: 4, height: 4) { Bevel.fill(CGRect(x: 0, y: 0, width: 4, height: 4), color: red, context: $0) }
    let image = PixelCanvas.render(width: 4, height: 4) { icon.drawDimmed(at: .zero, context: $0) }
    #expect(image.color(x: 0, y: 0) == red)
    #expect(image.color(x: 1, y: 0) == .white)
    #expect(image.color(x: 0, y: 1) == .white)
    #expect(image.color(x: 1, y: 1) == red)
}
