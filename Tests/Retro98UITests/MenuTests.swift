import Testing
@testable import Retro98UI

@Test func wrapsIntoColumnsWhenTallerThanScreen() {
    let layout = RetroMenuLayout.columns(itemHeights: Array(repeating: 20, count: 50), maxHeight: 400)
    #expect(layout.columns.count == 3)
    #expect(layout.columns[0].count == 20)
    #expect(layout.columns.flatMap { $0 } == Array(0..<50))
}

@Test func singleColumnWhenItFits() {
    #expect(RetroMenuLayout.columns(itemHeights: Array(repeating: 20, count: 5), maxHeight: 400).columns
            == [[0, 1, 2, 3, 4]])
}

@Test func separatorsCountTheirOwnHeight() {
    #expect(RetroMenuLayout.columns(itemHeights: [20, 8, 20], maxHeight: 28).columns == [[0, 1], [2]])
}

@Test func emptyMenuHasNoColumns() {
    #expect(RetroMenuLayout.columns(itemHeights: [], maxHeight: 400).columns.isEmpty)
}

@Test func keyboardNavigationSkipsSeparatorsAndDisabledItems() {
    let selectable = [true, false, false, true, true]   // 1 = separator, 2 = disabled
    #expect(RetroMenuNavigation.next(from: nil, direction: .down, selectable: selectable) == 0)
    #expect(RetroMenuNavigation.next(from: 0, direction: .down, selectable: selectable) == 3)
    #expect(RetroMenuNavigation.next(from: 4, direction: .down, selectable: selectable) == 0)
    #expect(RetroMenuNavigation.next(from: 0, direction: .up, selectable: selectable) == 4)
    #expect(RetroMenuNavigation.next(from: nil, direction: .up, selectable: selectable) == 4)
    #expect(RetroMenuNavigation.next(from: nil, direction: .down, selectable: [false, false]) == nil)
}

@Test func ignoreClickPredicateIsConsulted() {
    #expect(RetroMenu.shouldClose(clickInMenu: false, ignored: false))
    #expect(!RetroMenu.shouldClose(clickInMenu: true, ignored: false))
    #expect(!RetroMenu.shouldClose(clickInMenu: false, ignored: true))
}
