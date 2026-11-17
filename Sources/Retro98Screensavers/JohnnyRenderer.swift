import AppKit

// MARK: - Public renderer

/// Johnny Castaway screensaver — pixel art original, não baseado em assets da Sierra.
@MainActor
public final class JohnnyRenderer: ScreensaverRenderer {
    private var johnnyView: JohnnyView?
    private var timer: Timer?

    public private(set) var currentSceneKind: JohnnySceneKind = .idle
    public private(set) var currentFrame: Int = 0
    private var sceneElapsed: TimeInterval = 0
    private var frameElapsed: TimeInterval = 0
    private let tickInterval: TimeInterval = 0.1
    private static let sceneSequence: [JohnnySceneKind] = [
        .idle, .sleeping, .fishing, .shark, .idle, .bird, .stretching
    ]
    private var sceneIndex = 0

    public init() {}

    public func start(in view: NSView) {
        let jv = JohnnyView(frame: view.bounds)
        jv.autoresizingMask = [.width, .height]
        jv.renderer = self
        view.addSubview(jv)
        johnnyView = jv
        startSceneForTesting()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInternal() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        johnnyView?.removeFromSuperview()
        johnnyView = nil
    }

    public func startSceneForTesting() {
        sceneIndex = 0
        currentSceneKind = Self.sceneSequence[0]
        currentFrame = 0
        sceneElapsed = 0
        frameElapsed = 0
    }

    public func advanceSceneForTesting() {
        sceneIndex = (sceneIndex + 1) % Self.sceneSequence.count
        currentSceneKind = Self.sceneSequence[sceneIndex]
        currentFrame = 0
        sceneElapsed = 0
        frameElapsed = 0
    }

    public func tickFrameForTesting() { tickInternal() }

    public func renderFrameForTesting(size: CGSize) -> NSImage? {
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return nil }
        JohnnyScene.draw(currentSceneKind, frame: currentFrame, in: ctx, size: size)
        img.unlockFocus()
        return img
    }

    private func tickInternal() {
        frameElapsed += tickInterval
        sceneElapsed += tickInterval
        let scene = currentSceneKind
        if frameElapsed >= scene.frameDuration {
            frameElapsed = 0
            currentFrame = (currentFrame + 1) % scene.frameCount
            johnnyView?.needsDisplay = true
        }
        if sceneElapsed >= scene.sceneDuration {
            advanceSceneForTesting()
            johnnyView?.needsDisplay = true
        }
    }
}

// MARK: - Scene kind

public enum JohnnySceneKind: CaseIterable {
    case idle, sleeping, fishing, shark, bird, stretching

    var frameCount: Int {
        switch self {
        case .idle: 2; case .sleeping: 2; case .fishing: 3
        case .shark: 4; case .bird: 3; case .stretching: 2
        }
    }
    var frameDuration: TimeInterval {
        switch self {
        case .idle: 1.5; case .sleeping: 3.0; case .fishing: 2.0
        case .shark: 0.8; case .bird: 0.6; case .stretching: 1.0
        }
    }
    var sceneDuration: TimeInterval {
        switch self {
        case .idle: 7; case .sleeping: 10; case .fishing: 10
        case .shark: 5; case .bird: 4; case .stretching: 3
        }
    }
}

// MARK: - View

final class JohnnyView: NSView {
    weak var renderer: JohnnyRenderer?

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let r = renderer else { return }
        JohnnyScene.draw(r.currentSceneKind, frame: r.currentFrame, in: ctx, size: bounds.size)
    }
}

// MARK: - Pixel art engine

// Virtual canvas size: 320 × 180 (16:9). One "virtual pixel" maps to ps real pixels.
// y=0 is top after the transform applied in JohnnyScene.draw.

private let charToColor: [Character: UInt8] = [
    " ": 0,
    "O": 1, "o": 2, "~": 3,     // ocean
    "S": 4, "s": 5,              // sand
    "k": 6, "K": 7,              // skin
    "b": 8, "B": 9,              // shirt blue
    "p": 10, "P": 11,            // pants
    "T": 12, "t": 13,            // palm trunk
    "g": 14, "G": 15,            // palm leaf
    "r": 16, "R": 17,            // rock
    "w": 18, "#": 19,            // white / outline
    "Z": 20, "z": 21,            // shark
    "h": 22,                     // hair
]

// (red, green, blue, alpha)
private let palette: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (0.00, 0.00, 0.00, 0.00),   //  0 transparent
    (0.00, 0.22, 0.42, 1.00),   //  1 ocean dark
    (0.05, 0.38, 0.62, 1.00),   //  2 ocean mid
    (0.15, 0.55, 0.80, 1.00),   //  3 ocean light
    (0.85, 0.76, 0.52, 1.00),   //  4 sand
    (0.70, 0.60, 0.38, 1.00),   //  5 sand dark
    (0.92, 0.72, 0.52, 1.00),   //  6 skin
    (0.75, 0.56, 0.36, 1.00),   //  7 skin shadow
    (0.22, 0.32, 0.68, 1.00),   //  8 shirt blue
    (0.14, 0.20, 0.50, 1.00),   //  9 shirt dark
    (0.38, 0.24, 0.10, 1.00),   // 10 pants brown
    (0.24, 0.14, 0.04, 1.00),   // 11 pants dark
    (0.52, 0.35, 0.14, 1.00),   // 12 trunk brown
    (0.36, 0.22, 0.06, 1.00),   // 13 trunk dark
    (0.22, 0.58, 0.22, 1.00),   // 14 leaf green
    (0.12, 0.40, 0.12, 1.00),   // 15 leaf dark
    (0.54, 0.54, 0.58, 1.00),   // 16 rock
    (0.38, 0.38, 0.42, 1.00),   // 17 rock dark
    (1.00, 1.00, 1.00, 1.00),   // 18 white
    (0.08, 0.08, 0.10, 1.00),   // 19 black/outline
    (0.32, 0.32, 0.50, 1.00),   // 20 shark
    (0.20, 0.20, 0.36, 1.00),   // 21 shark dark
    (0.42, 0.26, 0.08, 1.00),   // 22 hair brown
]

private func palColor(_ idx: UInt8) -> CGColor {
    guard Int(idx) < palette.count else { return CGColor.clear }
    let (r, g, b, a) = palette[Int(idx)]
    return CGColor(red: r, green: g, blue: b, alpha: a)
}

// Renders a sprite at virtual-pixel (vx, vy) with one virtual pixel = ps points.
private func spr(_ rows: [String], vx: Int, vy: Int, ps: CGFloat, in ctx: CGContext) {
    for (ri, row) in rows.enumerated() {
        for (ci, ch) in row.enumerated() {
            guard let idx = charToColor[ch], idx != 0 else { continue }
            ctx.setFillColor(palColor(idx))
            ctx.fill(CGRect(x: CGFloat(vx + ci) * ps, y: CGFloat(vy + ri) * ps,
                            width: ps, height: ps))
        }
    }
}

// MARK: - Sprites

// Palm tree — 12 wide × 24 tall; y=0 is top of fronds, y=23 is root line.
private let sPalm: [String] = [
    "   gg g     ",  //  0 fronds top
    "  gGggg     ",  //  1
    " gGGGgg     ",  //  2
    "  gGgg      ",  //  3
    " gGGg  g    ",  //  4
    "  Ggg gGg   ",  //  5
    "   g gGGg   ",  //  6
    "    gGGgg   ",  //  7
    "    gGgg    ",  //  8
    "    gGg     ",  //  9
    "     tT     ",  // 10 trunk
    "     tT     ",  // 11
    "     Tt     ",  // 12
    "     tT     ",  // 13
    "     Tt     ",  // 14
    "    tTt     ",  // 15
    "     Tt     ",  // 16
    "     Tt     ",  // 17
    "    tTt     ",  // 18
    "     TT     ",  // 19
    "    tTT     ",  // 20
    "     TT     ",  // 21
    "    tTT     ",  // 22
    "    tTT     ",  // 23
]

// Johnny standing, frame 0 — 8 wide × 18 tall.
private let sJStand0: [String] = [
    " #hh#  ",   //  0 head
    "#hkkk# ",   //  1
    "#kkkk# ",   //  2
    "#Kkkk# ",   //  3
    " #hh#  ",   //  4 neck
    "##bb## ",   //  5 shoulders
    "#bbbb# ",   //  6 shirt
    "#bBbb# ",   //  7
    "#bbBb# ",   //  8
    "#Bbbb# ",   //  9
    "##BB## ",   // 10 waist
    " #pp#  ",   // 11 pants
    "#pp pp#",   // 12 legs
    "#Pp pp#",   // 13 frame 0: left behind
    "#pp Pp#",   // 14
    " #pp#  ",   // 15
    " #Pp#  ",   // 16
    "  ##   ",   // 17 feet
]

// Johnny standing, frame 1 — 8 wide × 18 tall (legs swapped).
private let sJStand1: [String] = [
    " #hh#  ",
    "#hkkk# ",
    "#kkkk# ",
    "#Kkkk# ",
    " #hh#  ",
    "##bb## ",
    "#bbbb# ",
    "#bBbb# ",
    "#bbBb# ",
    "#Bbbb# ",
    "##BB## ",
    " #pp#  ",
    "#pp pp#",
    "#pp Pp#",   // frame 1: right behind
    "#Pp pp#",
    " #pp#  ",
    " #Pp#  ",
    "  ##   ",
]

// Johnny sleeping, frame 0 — 20 wide × 8 tall.
private let sJSleep0: [String] = [
    "          #hh#      ",
    "###BB### #hkkk#     ",
    "#bbbbbbb#kkkK##     ",
    "#bBBBbbb#kkk#       ",
    "###pppp#####        ",
    "  #pppp#            ",
    "   ####             ",
    "                    ",
]

// Johnny sleeping, frame 1 — 20 wide × 8 tall (Zzz shown).
private let sJSleep1: [String] = [
    "          #hh#  w   ",
    "###BB### #hkkk# ww  ",
    "#bbbbbbb#kkkK## w   ",
    "#bBBBbbb#kkk#       ",
    "###pppp#####        ",
    "  #pppp#            ",
    "   ####             ",
    "                    ",
]

// Johnny fishing, frame 0 — 18 wide × 18 tall.
private let sJFish0: [String] = [
    " #hh#          ",
    "#hkkk#         ",
    "#kkkk#         ",
    "#Kkkk#         ",
    " #hh#          ",
    "##bbbT#        ",
    "#bbbbbTt       ",
    "#bBbbbTt       ",
    "#bbBbb#  t     ",
    "#Bbbbb#        ",
    "##BB###        ",
    " #pp#          ",
    "#pp pp#        ",
    "#Pp pp#        ",
    "#pp Pp#        ",
    " #pp#          ",
    " #Pp#          ",
    "  ##           ",
]

// Johnny fishing, frame 1 — line in water.
private let sJFish1: [String] = [
    " #hh#          ",
    "#hkkk#         ",
    "#kkkk#         ",
    "#Kkkk#         ",
    " #hh#          ",
    "##bbbT#        ",
    "#bbbbbTt       ",
    "#bBbbbTt       ",
    "#bbBbb#  t     ",
    "#Bbbbb#   #    ",
    "##BB###        ",
    " #pp#          ",
    "#pp pp#        ",
    "#Pp pp#        ",
    "#pp Pp#        ",
    " #pp#          ",
    " #Pp#          ",
    "  ##           ",
]

// Johnny fishing, frame 2 — fish on line.
private let sJFish2: [String] = [
    " #hh#          ",
    "#hkkk#         ",
    "#kkkk#         ",
    "#Kkkk#         ",
    " #hh#          ",
    "##bbbT#        ",
    "#bbbbbTt       ",
    "#bBbbbTt       ",
    "#bbBbb#  t     ",
    "#Bbbbb#   #    ",
    "##BB###   o    ",
    " #pp#          ",
    "#pp pp#        ",
    "#Pp pp#        ",
    "#pp Pp#        ",
    " #pp#          ",
    " #Pp#          ",
    "  ##           ",
]

// Johnny stretching, arms down, frame 0 — 10 wide × 18 tall.
private let sJStretch0: [String] = [
    "  #hh#    ",
    " #hkkk#   ",
    " #kkkk#   ",
    " #Kkkk#   ",
    "  #hh#    ",
    "k##bbb##  ",
    "#kbbbbbbk ",
    " ##bbbb## ",
    " ##bBbb## ",
    " ##BBbb## ",
    "  ##BB##  ",
    "   #pp#   ",
    "  #pp pp# ",
    "  #Pp pp# ",
    "  #pp Pp# ",
    "   #pp#   ",
    "   #Pp#   ",
    "    ##    ",
]

// Johnny stretching, arms up, frame 1 — 10 wide × 18 tall.
private let sJStretch1: [String] = [
    "k  #hh#  k",
    "k ##hkk## ",
    " ##kkkkk##",
    "  ##Kkkk# ",
    "   ##hh#  ",
    "   ##bb## ",
    "   #bbbb# ",
    "   #bBbb# ",
    "   #bbBb# ",
    "   #Bbbbb ",
    "   ##BB## ",
    "    #pp#  ",
    "   #pp pp#",
    "   #Pp pp#",
    "   #pp Pp#",
    "    #pp#  ",
    "    #Pp#  ",
    "     ##   ",
]

// Shark fin — 12 wide × 6 tall.
private let sSharkFin: [String] = [
    "     Z      ",
    "    zZZ     ",
    "   zZZZz    ",
    "  zZZZZZz   ",
    " #ZZZZZZZ#  ",
    " ########## ",
]

// Bird sprites — 8 wide × 4 tall, 3 animation frames.
private let sBird0: [String] = [   // wings up
    "  #  #  ",
    " #k  k# ",
    "#kk  kk#",
    "  #  #  ",
]

private let sBird1: [String] = [   // wings mid
    "        ",
    "#k    k#",
    " ##  ## ",
    "   ##   ",
]

private let sBird2: [String] = [   // wings down
    "   ##   ",
    " ##  ## ",
    "#k    k#",
    "        ",
]

// MARK: - Scene composition

enum JohnnyScene {

    // Virtual canvas dimensions
    static let vw: CGFloat = 320
    static let vh: CGFloat = 180

    static func draw(_ scene: JohnnySceneKind, frame: Int, in ctx: CGContext, size: CGSize) {
        // Fit virtual canvas into real screen, centred.
        let ps = min(size.width / vw, size.height / vh)
        let ox = (size.width  - vw * ps) / 2
        let oy = (size.height - vh * ps) / 2

        // Flip y so virtual y=0 is screen top (sprites use top-left origin).
        ctx.saveGState()
        ctx.translateBy(x: ox, y: oy + vh * ps)
        ctx.scaleBy(x: 1, y: -1)

        drawBackground(ps: ps, in: ctx)
        drawIsland(ps: ps, in: ctx)

        // Palm tree: roots align to island top at vy=130, sprite is 24 tall → vy = 130 - 24 = 106.
        spr(sPalm, vx: 170, vy: 106, ps: ps, in: ctx)

        switch scene {
        case .idle:
            spr(frame == 0 ? sJStand0 : sJStand1, vx: 136, vy: 112, ps: ps, in: ctx)

        case .sleeping:
            spr(frame == 0 ? sJSleep0 : sJSleep1, vx: 120, vy: 136, ps: ps, in: ctx)

        case .fishing:
            let fishFrames = [sJFish0, sJFish1, sJFish2]
            spr(fishFrames[frame % 3], vx: 128, vy: 112, ps: ps, in: ctx)

        case .shark:
            spr(sJStand0, vx: 136, vy: 112, ps: ps, in: ctx)
            let finX = Int(CGFloat(frame) / 4.0 * vw) - 20
            spr(sSharkFin, vx: finX, vy: 148, ps: ps, in: ctx)

        case .bird:
            spr(sJStand0, vx: 136, vy: 112, ps: ps, in: ctx)
            let birdFrames = [sBird0, sBird1, sBird2]
            let birdX = Int(CGFloat(frame) / 3.0 * (vw + 40)) - 20
            spr(birdFrames[frame % 3], vx: birdX, vy: 86, ps: ps, in: ctx)

        case .stretching:
            spr(frame == 0 ? sJStretch0 : sJStretch1, vx: 134, vy: 112, ps: ps, in: ctx)
        }

        ctx.restoreGState()
    }

    // Ocean background with horizon bands.
    private static func drawBackground(ps: CGFloat, in ctx: CGContext) {
        ctx.setFillColor(palColor(1))
        ctx.fill(CGRect(x: 0, y: 0, width: vw * ps, height: vh * ps))

        ctx.setFillColor(palColor(2))
        for vy in [100, 112, 124] {
            ctx.fill(CGRect(x: 0, y: CGFloat(vy) * ps, width: vw * ps, height: 2 * ps))
        }

        ctx.setFillColor(palColor(3))
        ctx.fill(CGRect(x: 0, y: 118 * ps, width: vw * ps, height: ps))
    }

    // Sand island ellipse with rock.
    private static func drawIsland(ps: CGFloat, in ctx: CGContext) {
        // Island: centre (160, 143), 92 wide, 28 tall.
        let cx: CGFloat = 160, cy: CGFloat = 143, iw: CGFloat = 92, ih: CGFloat = 28
        ctx.setFillColor(palColor(5))
        ctx.fillEllipse(in: CGRect(x: (cx - iw / 2 - 2) * ps, y: (cy - ih / 2 - 2) * ps,
                                   width: (iw + 4) * ps, height: (ih + 4) * ps))
        ctx.setFillColor(palColor(4))
        ctx.fillEllipse(in: CGRect(x: (cx - iw / 2) * ps, y: (cy - ih / 2) * ps,
                                   width: iw * ps, height: ih * ps))

        // Rock on the left side of island.
        ctx.setFillColor(palColor(17))
        ctx.fillEllipse(in: CGRect(x: 118 * ps, y: 136 * ps, width: 10 * ps, height: 7 * ps))
        ctx.setFillColor(palColor(16))
        ctx.fillEllipse(in: CGRect(x: 119 * ps, y: 137 * ps, width: 8 * ps, height: 5 * ps))
    }
}
