import AppKit
import Retro98Settings
import Retro98UI
import UniformTypeIdentifiers

/// The Display dialog: the macOS wallpaper, one of 16 solid colors, or a picture, with a monitor preview.
@MainActor
final class DisplayApplet {
    static let colors = ["#008080", "#000080", "#008000", "#800000", "#800080", "#808000", "#808080", "#C0C0C0",
                         "#000000", "#FFFFFF", "#0000FF", "#00FF00", "#FF0000", "#FF00FF", "#FFFF00", "#00FFFF"]
    static let width: CGFloat = 360
    static let height: CGFloat = 266
    static let swatchSize: CGFloat = 18

    /// What OK would show; `newPicture` still has to be copied in.
    enum Pending: Equatable {
        case macOS
        case color(String)
        case currentPicture(WallpaperChoice)
        case newPicture(URL)
    }

    let dialog: AppletDialog
    let preview = MonitorPreview()
    private(set) var macOSOption: RetroRadioButton!
    private(set) var colorOption: RetroRadioButton!
    private(set) var pictureOption: RetroRadioButton!
    private(set) var swatches: [ColorSwatch] = []
    private let pictureName = RetroLabel(lines: [""])
    private(set) var pending: Pending = .macOS
    private var current: WallpaperChoice?
    private let model: ControlPanelModel
    private let services: ControlPanelServices
    private let prompter: ControlPanelPrompter
    private let pickPicture: @MainActor () -> URL?

    init(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter,
         pickPicture: @escaping @MainActor () -> URL? = DisplayApplet.choosePicture) {
        self.model = model
        self.services = services
        self.prompter = prompter
        self.pickPicture = pickPicture
        dialog = AppletDialog(title: Applet.display.title(services.languages), contentSize: CGSize(width: Self.width, height: Self.height),
                              languages: services.languages)
        build()
        dialog.onApply = { [weak self] in self?.apply() }
        refresh()
    }

    private func build() {
        let l = services.languages
        let content = dialog.contentView
        let margin = AppletDialog.margin
        preview.frame = CGRect(x: ((Self.width - MonitorPreview.size.width) / 2).rounded(), y: margin,
                               width: MonitorPreview.size.width, height: MonitorPreview.size.height)
        content.addSubview(preview)
        var y = preview.frame.maxY + margin
        macOSOption = RetroRadioButton(title: ControlPanelText.macOSWallpaper(l), isSelected: true) { [weak self] in self?.select(.macOS) }
        macOSOption.frame.origin = CGPoint(x: margin, y: y)
        content.addSubview(macOSOption)
        y += 22
        colorOption = RetroRadioButton(title: ControlPanelText.solidColor(l), isSelected: false) { [weak self] in
            guard let self else { return }
            if case .color = pending { return }
            select(.color(Self.colors[0]))
        }
        colorOption.frame.origin = CGPoint(x: margin, y: y)
        content.addSubview(colorOption)
        let swatchesX = margin + colorOption.frame.width + margin
        for (index, hex) in Self.colors.enumerated() {
            let swatch = ColorSwatch(hex: hex) { [weak self] in self?.clickSwatch(index) }
            swatch.frame = CGRect(x: swatchesX + CGFloat(index % 8) * (Self.swatchSize + 2), y: y - 2 + CGFloat(index / 8) * (Self.swatchSize + 2),
                                  width: Self.swatchSize, height: Self.swatchSize)
            content.addSubview(swatch)
            swatches.append(swatch)
        }
        y += 2 * (Self.swatchSize + 2) + 6
        pictureOption = RetroRadioButton(title: ControlPanelText.picture(l), isSelected: false) { [weak self] in
            guard let self else { return }
            switch pending {
            case .currentPicture, .newPicture: return
            default: browse()
            }
        }
        pictureOption.frame.origin = CGPoint(x: margin, y: y)
        content.addSubview(pictureOption)
        let browseTitle = ControlPanelText.browse(l)
        let browse = RetroButton(title: browseTitle) { [weak self] in self?.browse() }
        let browseSize = RetroButton.preferredSize(title: browseTitle, icon: nil, bold: false)
        browse.frame = CGRect(x: Self.width - margin - browseSize.width, y: y - 4, width: browseSize.width, height: browseSize.height)
        content.addSubview(browse)
        pictureName.frame = CGRect(x: swatchesX, y: y, width: browse.frame.minX - swatchesX - 6, height: CGFloat(PixelText.lineHeight))
        content.addSubview(pictureName)
        y += 30
        let displays = macOSButton(ControlPanelText.macOSDisplays(l), .displays, services: services)
        displays.frame.origin = CGPoint(x: margin, y: y)
        content.addSubview(displays)
    }

    /// Back to what is applied now.
    func refresh() {
        current = try? model.wallpaper()
        switch current {
        case nil: select(.macOS)
        case .color(let hex): select(.color(hex))
        case .picture?: select(.currentPicture(current!))
        }
    }

    func select(_ choice: Pending) {
        pending = choice
        macOSOption.isSelected = choice == .macOS
        let hex: String? = if case .color(let hex) = choice { hex } else { nil }
        colorOption.isSelected = hex != nil
        for swatch in swatches { swatch.isChosen = swatch.hex == hex }
        switch choice {
        case .macOS:
            pictureOption.isSelected = false
            preview.show(.macOS)
        case .color(let hex):
            pictureOption.isSelected = false
            preview.show(.color(hex))
        case .currentPicture(.picture(let path, let name)):
            pictureOption.isSelected = true
            pictureName.lines = [RetroText.fit(name, maxWidth: Int(pictureName.frame.width))]
            preview.show(.picture(URL(filePath: path)))
        case .currentPicture:
            break
        case .newPicture(let url):
            pictureOption.isSelected = true
            pictureName.lines = [RetroText.fit(url.lastPathComponent, maxWidth: Int(pictureName.frame.width))]
            preview.show(.picture(url))
        }
    }

    func clickSwatch(_ index: Int) {
        select(.color(Self.colors[index]))
    }

    /// Picks a picture; anything macOS can't open as an image is refused here, before anything changes.
    func browse() {
        guard let url = pickPicture() else { return }
        guard NSImage(contentsOf: url) != nil else {
            presentProblems([.notAnImage(name: url.lastPathComponent)], model: model, services: services, prompter: prompter)
            return
        }
        select(.newPicture(url))
    }

    private func apply() {
        let problems: [Problem]
        switch pending {
        case .macOS:
            guard current != nil else { return }
            problems = model.setWallpaper(nil)
        case .color(let hex):
            guard current != .color(hex: hex) else { return }
            problems = model.setWallpaper(.color(hex: hex))
        case .currentPicture:
            return
        case .newPicture(let url):
            do {
                problems = model.setWallpaper(try services.adoptPicture(url))
            } catch PictureWallpaperError.notAnImage {
                problems = [.notAnImage(name: url.lastPathComponent)]
            } catch {
                problems = [.fileFailed(String(describing: error))]
            }
        }
        presentProblems(problems, model: model, services: services, prompter: prompter)
        refresh()
    }

    static func choosePicture() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// A small 98-style monitor showing the chosen color, the picture, or "macOS".
@MainActor
final class MonitorPreview: PixelView {
    static let size = CGSize(width: 152, height: 112)

    enum Content: Equatable {
        case macOS, color(String), picture(URL)
    }

    private(set) var content = Content.macOS
    private var image: CGImage?

    func show(_ content: Content) {
        self.content = content
        if case .picture(let url) = content {
            image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        } else {
            image = nil
        }
        needsDisplay = true
    }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        let body = CGRect(x: 16, y: 0, width: size.width - 32, height: size.height - 16)
        Bevel.fill(body, color: Palette.face, context: context)
        Bevel.draw(.raised, in: body, context: context)
        let screen = body.insetBy(dx: 10, dy: 10)
        Bevel.draw(.sunken, in: screen, context: context)
        let inside = screen.insetBy(dx: 2, dy: 2)
        switch content {
        case .macOS:
            Bevel.fill(inside, color: Palette.shadow, context: context)
            let width = CGFloat(PixelText.width(of: "macOS", font: .regular))
            PixelText.draw("macOS", font: .regular, color: .white,
                           at: CGPoint(x: (inside.midX - width / 2).rounded(), y: (inside.midY - CGFloat(PixelText.lineHeight) / 2).rounded()),
                           context: context)
        case .color(let hex):
            Bevel.fill(inside, color: PixelColor.parse(hex) ?? Palette.desktop, context: context)
        case .picture:
            if let image {
                PixelIcon.drawUpright(image, in: inside, context: context)
            } else {
                Bevel.fill(inside, color: .black, context: context)
            }
        }
        let foot = CGRect(x: size.width / 2 - 20, y: body.maxY, width: 40, height: 6)
        Bevel.fill(foot, color: Palette.shadow, context: context)
        let base = CGRect(x: size.width / 2 - 34, y: foot.maxY, width: 68, height: 8)
        Bevel.fill(base, color: Palette.face, context: context)
        Bevel.draw(.raised, in: base, context: context)
    }
}

/// One color in the Display dialog; the chosen one gets a black frame.
@MainActor
final class ColorSwatch: PixelView {
    let hex: String
    var isChosen = false { didSet { needsDisplay = true } }
    private let onClick: () -> Void

    init(hex: String, onClick: @escaping () -> Void) {
        self.hex = hex
        self.onClick = onClick
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func mouseDown(with event: NSEvent) { onClick() }

    override func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        Bevel.draw(.field, in: rect, context: context)
        Bevel.fill(rect.insetBy(dx: 2, dy: 2), color: PixelColor.parse(hex) ?? .black, context: context)
        if isChosen {
            Bevel.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), color: .black, context: context)
            Bevel.fill(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height), color: .black, context: context)
        }
    }
}

private extension PixelColor {
    /// "#RRGGBB" to a color; nil for anything else.
    static func parse(_ hex: String) -> PixelColor? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return PixelColor(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }
}
