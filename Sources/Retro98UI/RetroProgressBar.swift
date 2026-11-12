import AppKit

/// A classic progress bar: a sunken status field filled left to right with navy blocks.
@MainActor
public final class RetroProgressBar: PixelView {
    nonisolated static let blockWidth: CGFloat = 8
    nonisolated static let gap: CGFloat = 2
    nonisolated static let margin: CGFloat = 2

    /// 0...1; values outside are clamped.
    public var fraction: Double = 0 { didSet { needsDisplay = true } }

    nonisolated public static func blockCount(fraction: Double, width: CGFloat) -> Int {
        let fitting = Int(((width - margin * 2 + gap) / (blockWidth + gap)).rounded(.down))
        return Int((Double(max(fitting, 0)) * min(max(fraction, 0), 1)).rounded(.down))
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        Bevel.draw(.statusField, in: rect, context: context)
        for block in 0..<Self.blockCount(fraction: fraction, width: size.width) {
            let x = Self.margin + CGFloat(block) * (Self.blockWidth + Self.gap)
            Bevel.fill(CGRect(x: x, y: Self.margin, width: Self.blockWidth, height: size.height - Self.margin * 2),
                       color: Palette.selection, context: context)
        }
    }
}
