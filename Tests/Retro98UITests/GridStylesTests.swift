import AppKit
import Testing
@testable import Retro98UI

private let detailColumns = [GridColumn(title: "Nome", width: 0), GridColumn(title: "Tamanho", width: 80, alignsRight: true),
                             GridColumn(title: "Tipo", width: 150), GridColumn(title: "Modificado", width: 130)]

// MARK: Geometry

@Test func smallIconsFlowInRows() {
    let geometry = IconGridGeometry(style: .smallIcons, visibleSize: CGSize(width: 470, height: 300), count: 10)
    #expect(geometry.frame(of: 4) == CGRect(x: 158, y: 28, width: 150, height: 20))
    #expect(geometry.contentSize == CGSize(width: 470, height: 300))
}

@Test func listFlowsInColumnsAndScrollsSideways() {
    let geometry = IconGridGeometry(style: .list, visibleSize: CGSize(width: 300, height: 106), count: 12)
    #expect(geometry.frame(of: 7) == CGRect(x: 188, y: 44, width: 180, height: 18))
    #expect(geometry.contentSize == CGSize(width: 8 * 2 + 3 * 180, height: 106))
}

@Test func detailsRowsStack() {
    let geometry = IconGridGeometry(style: .details, visibleSize: CGSize(width: 500, height: 300), count: 30)
    #expect(geometry.frame(of: 3) == CGRect(x: 0, y: 54, width: 500, height: 18))
    #expect(geometry.contentSize == CGSize(width: 500, height: 540))
}

@Test func indexAtPointPerStyle() {
    for style in [IconGridStyle.largeIcons, .smallIcons, .list, .details] {
        let geometry = IconGridGeometry(style: style, visibleSize: CGSize(width: 470, height: 300), count: 20)
        let cell = geometry.frame(of: 5)
        #expect(geometry.index(at: CGPoint(x: cell.midX, y: cell.midY)) == 5, "\(style)")
        #expect(geometry.index(at: CGPoint(x: -5, y: -5)) == nil, "\(style)")
    }
}

@Test func arrowsPerStyle() {
    let list = IconGridGeometry(style: .list, visibleSize: CGSize(width: 300, height: 106), count: 20)
    #expect(list.move(from: 2, .down) == 3)
    #expect(list.move(from: 2, .right) == 7)
    let details = IconGridGeometry(style: .details, visibleSize: CGSize(width: 300, height: 300), count: 20)
    #expect(details.move(from: 2, .up) == 1)
    #expect(details.move(from: 2, .down) == 3)
    #expect(details.move(from: 2, .left) == nil)
    let small = IconGridGeometry(style: .smallIcons, visibleSize: CGSize(width: 470, height: 300), count: 20)
    #expect(small.move(from: 1, .down) == 4)
    #expect(small.move(from: nil, .down) == 0)
}

@Test func visibleIndicesStayBoundedInEveryStyle() {
    let visible = CGSize(width: 450, height: 300)
    for style in [IconGridStyle.largeIcons, .smallIcons, .list, .details] {
        let geometry = IconGridGeometry(style: style, visibleSize: visible, count: 10_000)
        let middle = geometry.frame(of: 5_000)
        let window = CGRect(origin: CGPoint(x: style == .list ? middle.minX : 0, y: style == .list ? 0 : middle.minY), size: visible)
        let indices = geometry.indices(in: window)
        #expect(!indices.isEmpty && indices.count <= 100, "\(style): \(indices.count)")
    }
}

@Test func columnWidthsGiveTheRestToName() {
    #expect(GridColumn.widths(detailColumns, totalWidth: 520) == [160, 80, 150, 130])
    #expect(GridColumn.widths(detailColumns, totalWidth: 1000) == [640, 80, 150, 130])
}

// MARK: Grid

@MainActor private final class Source: RetroIconGridDataSource {
    func numberOfItems(in grid: RetroIconGrid) -> Int { 12 }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { "item \(index)" }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { FileIcons.icon(.document, size: 32) }
    func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String] { ["1 KB", "Documento", "hoje"] }
}

@MainActor private func makeGrid() -> (RetroIconGrid, Source, NSWindow) {
    let source = Source(), grid = RetroIconGrid()
    grid.dataSource = source
    grid.columns = detailColumns
    let scroll = RetroScroller.makeScrollView(document: grid)
    scroll.frame = CGRect(x: 0, y: 0, width: 470, height: 300)
    let window = NSWindow(contentRect: scroll.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = scroll
    grid.reloadData()
    window.makeFirstResponder(grid)
    return (grid, source, window)
}

@MainActor @Test func editorSitsOnTheLabelInEveryStyle() throws {
    let (grid, source, window) = makeGrid()
    defer { withExtendedLifetime((source, window)) {} }
    for style in [IconGridStyle.smallIcons, .list, .details] {
        grid.style = style
        grid.beginEditing(at: 1, text: "nome", selecting: NSRange(location: 0, length: 4))
        let field = try #require(grid.editor)
        let cell = IconGridGeometry(style: style, visibleSize: try #require(grid.superview).bounds.size, count: 12).frame(of: 1)
        #expect(field.frame.minX == cell.minX + 20, "\(style)")
        grid.endEditing(commit: false)
    }
}

@MainActor @Test func styleChangeKeepsSelection() {
    let (grid, source, window) = makeGrid()
    defer { withExtendedLifetime((source, window)) {} }
    grid.setSelection([2, 3])
    grid.style = .details
    #expect(grid.selection == [2, 3])
    grid.style = .list
    #expect(grid.selection == [2, 3])
}

@MainActor @Test func rubberBandSelectsInEveryStyle() {
    let (grid, source, window) = makeGrid()
    defer { withExtendedLifetime((source, window)) {} }
    for style in [IconGridStyle.largeIcons, .smallIcons, .list, .details] {
        grid.style = style
        let geometry = IconGridGeometry(style: style, visibleSize: grid.superview?.bounds.size ?? .zero, count: 12)
        let band = geometry.frame(of: 0).union(geometry.frame(of: 1)).insetBy(dx: 2, dy: 2)
        #expect(grid.items(touching: band).isSuperset(of: [0, 1]), "\(style)")
    }
}

@MainActor @Test func headerClickReportsTheColumn() {
    let header = RetroColumnHeader(frame: CGRect(x: 0, y: 0, width: 520, height: 20))
    header.columns = detailColumns
    let window = NSWindow(contentRect: header.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = header
    var clicked: [Int] = []
    header.onClick = { clicked.append($0) }
    let point = header.convert(CGPoint(x: 160 + 80 + 10, y: 10), to: nil)
    header.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                                              windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
    #expect(clicked == [2])
}

@MainActor @Test func checkBoxToggles() {
    var changes: [Bool] = []
    let box = RetroCheckBox(title: "Incluir subpastas", isOn: false) { changes.append($0) }
    box.performClick()
    #expect(box.isOn)
    box.performClick()
    #expect(!box.isOn)
    #expect(changes == [true, false])
}

@MainActor @Test func disabledCheckBoxIgnoresClicksAndDrawsGray() {
    var changes: [Bool] = []
    let box = RetroCheckBox(title: "Barra de tarefas", isOn: false) { changes.append($0) }
    box.isEnabled = false
    box.performClick()
    #expect(!box.isOn)
    #expect(changes.isEmpty)
    #expect(!box.acceptsFirstResponder)
    let pixels = renderView(box)
    let labelX = Int(RetroCheckBox.boxSize + RetroCheckBox.labelGap)
    var gray = 0, black = 0
    for y in 0..<pixels.height {
        for x in labelX..<pixels.width {
            let color = pixels.color(x: x, y: y)
            if color == Palette.shadow { gray += 1 }
            if color == .black { black += 1 }
        }
    }
    #expect(gray > 0)
    #expect(black == 0)
}

@MainActor @Test func menuMarksDraw() {
    func blackPixels(_ mark: RetroMenuItem.Mark) -> Int {
        let image = PixelCanvas.render(width: 16, height: 16) { context in
            Bevel.fill(CGRect(x: 0, y: 0, width: 16, height: 16), color: Palette.face, context: context)
            RetroMenu.drawMark(mark, in: CGRect(x: 0, y: 0, width: 16, height: 16), color: .black, context: context)
        }
        return allPixels(image).filter { $0 == .black }.count
    }
    #expect(blackPixels(.check) > 0)
    #expect(blackPixels(.bullet) > 0)
    #expect(blackPixels(.none) == 0)
}

// MARK: Final review fixes

/// Details is as wide as its columns, so narrow windows scroll sideways instead of cutting columns off.
@Test func detailsContentFitsTheColumns() {
    let geometry = IconGridGeometry(style: .details, visibleSize: CGSize(width: 400, height: 300), count: 5, minimumWidth: 520)
    #expect(geometry.contentSize.width == 520)
    #expect(geometry.frame(of: 0).width == 520)
    let wide = IconGridGeometry(style: .details, visibleSize: CGSize(width: 700, height: 300), count: 5, minimumWidth: 520)
    #expect(wide.contentSize.width == 700)
}

@MainActor @Test func headerFollowsTheGridWidthAndScroll() {
    let header = RetroColumnHeader(frame: CGRect(x: 0, y: 0, width: 400, height: 20))
    header.columns = detailColumns
    header.contentWidth = 520
    #expect(header.column(at: 165) == 1)
    header.scrollOffset = 100
    #expect(header.column(at: 10) == 0)
    #expect(header.column(at: 70) == 1)
}

/// Only the icon and the name are an item in small icons, list and details; the rest is background.
@MainActor @Test func backgroundOfARowIsEmptySpace() throws {
    let (grid, source, window) = makeGrid()
    defer { withExtendedLifetime((source, window)) {} }
    grid.style = .details
    let row = IconGridGeometry(style: .details, visibleSize: try #require(grid.superview).bounds.size, count: 12).frame(of: 1)
    #expect(grid.itemIndex(at: CGPoint(x: 26, y: row.midY)) == 1)
    #expect(grid.itemIndex(at: CGPoint(x: 400, y: row.midY)) == nil)
    grid.style = .smallIcons
    let cell = IconGridGeometry(style: .smallIcons, visibleSize: try #require(grid.superview).bounds.size, count: 12).frame(of: 1)
    #expect(grid.itemIndex(at: CGPoint(x: cell.maxX - 3, y: cell.midY)) == nil)
    #expect(grid.itemIndex(at: CGPoint(x: cell.minX + 8, y: cell.midY)) == 1)
}

@MainActor @Test func scrollToItemShowsIt() {
    let source = ManySource(), grid = RetroIconGrid()
    grid.dataSource = source
    let scroll = RetroScroller.makeScrollView(document: grid)
    scroll.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
    grid.reloadData()
    grid.scrollToItem(250)
    #expect(grid.visibleRect.intersects(grid.itemFrame(250)))
    withExtendedLifetime(source) {}
}

@MainActor private final class ManySource: RetroIconGridDataSource {
    func numberOfItems(in grid: RetroIconGrid) -> Int { 300 }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { "f\(index)" }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { FileIcons.icon(.document, size: 32) }
}
