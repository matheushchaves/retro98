import AppKit

/// Original progress animation: a page hops in an arc from a folder on the left to a folder
/// (copy and move) or to the Recycle Bin (delete) on the right, 8 frames at 100 ms.
@MainActor
public final class FileOperationAnimation: PixelView {
    public enum Style: Sendable {
        case folderToFolder, folderToBin
    }

    nonisolated public static let frameCount = 8
    nonisolated static let iconSize: CGFloat = 32
    nonisolated static let pageSize: CGFloat = 16
    nonisolated static let arcHeight: CGFloat = 14
    static let frameDuration: TimeInterval = 0.1

    public var frameIndex = 0 { didSet { needsDisplay = true } }
    private let style: Style
    private var timer: Timer?

    public init(style: Style) {
        self.style = style
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Top-left of the page in a view `width` wide and 48 tall: over the left icon at frame 0,
    /// over the right one at the last frame, highest halfway.
    nonisolated public static func pageOrigin(frame: Int, width: CGFloat) -> CGPoint {
        let start = (iconSize - pageSize) / 2, end = width - iconSize + (iconSize - pageSize) / 2
        let progress = CGFloat(frame) / CGFloat(frameCount - 1)
        let baseline = (48 - iconSize) / 2 + (iconSize - pageSize) / 2
        return CGPoint(x: (start + (end - start) * progress).rounded(),
                       y: (baseline - arcHeight * sin(.pi * progress)).rounded())
    }

    public func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.frameDuration, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.frameIndex = (self.frameIndex + 1) % Self.frameCount
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        let iconY = ((size.height - Self.iconSize) / 2).rounded(.down)
        FileIcons.icon(.folder, size: 32).draw(at: CGPoint(x: 0, y: iconY), context: context)
        let target: FileIconKind = style == .folderToFolder ? .folder : .recycleBinEmpty
        FileIcons.icon(target, size: 32).draw(at: CGPoint(x: size.width - Self.iconSize, y: iconY), context: context)
        FileIcons.icon(.document, size: 16).draw(at: Self.pageOrigin(frame: frameIndex, width: size.width), context: context)
    }
}
