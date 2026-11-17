import AppKit
import SceneKit

/// 3D Pipes screensaver: colored pipes grow side by side through a 3D grid using SceneKit, turning now and then.
@MainActor
public final class PipesRenderer: ScreensaverRenderer {
    // MARK: - Grid
    static let totalCells = pipeGridX * pipeGridY * pipeGridZ
    static let resetFraction = 0.75
    /// How many pipes grow at once.
    static let pipeCount = 4
    /// The chance, at each step, that a pipe turns though it could go straight on.
    static let turnChance = 0.2
    /// The pipes' colors; the ones growing at once never share one.
    static let palette: [NSColor] = [
        NSColor(red: 0.9, green: 0.15, blue: 0.1, alpha: 1),
        NSColor(red: 1, green: 0.85, blue: 0.1, alpha: 1),
        NSColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1),
        NSColor(red: 0.25, green: 0.45, blue: 1, alpha: 1),
        NSColor(red: 0.1, green: 0.85, blue: 0.9, alpha: 1),
        NSColor(red: 0.9, green: 0.2, blue: 0.85, alpha: 1),
        NSColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1),
        NSColor(red: 1, green: 0.55, blue: 0.1, alpha: 1),
    ]

    private var occupied = Set<GridCell>()
    private var activePipes: [Pipe] = []
    private var scene: SCNScene?
    private var scnView: SCNView?
    private var timer: Timer?

    // MARK: - Test seams
    public private(set) var segmentCount = 0

    public init() {}

    public func start(in view: NSView) {
        let sv = SCNView(frame: view.bounds)
        sv.autoresizingMask = [.width, .height]
        sv.backgroundColor = .black
        sv.antialiasingMode = .multisampling4X
        view.addSubview(sv)
        scnView = sv
        buildScene(in: sv)
        startPipes()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        scnView?.removeFromSuperview()
        scnView = nil
    }

    // MARK: - Internal (also used by tests via startForTesting)

    func startForTesting() {
        scene = Self.makeScene()
        reset()
    }

    func tickForTesting() { tick() }

    var sceneForTesting: SCNScene? { scene }

    var pipesForTesting: [Pipe] { activePipes }

    var occupiedForTesting: Set<GridCell> { occupied }

    /// Fills every cell around pipe `index`, so it has nowhere left to grow.
    func blockPipeForTesting(at index: Int) {
        let pos = activePipes[index].position
        for d in GridDirection.allCases {
            let n = pos.moved(by: d)
            if n.isValid { occupied.insert(n) }
        }
    }

    /// Grows the pipes until the grid is as full as it gets before they start over.
    func fillGridForTesting() {
        for _ in 0..<Self.totalCells where !isFull { tick() }
    }

    func fillGridTo(fraction: Double) {
        let count = Int(Double(Self.totalCells) * fraction)
        var c = 0
        outer: for x in 0..<pipeGridX {
            for y in 0..<pipeGridY {
                for z in 0..<pipeGridZ {
                    if c >= count { break outer }
                    occupied.insert(GridCell(x: x, y: y, z: z))
                    c += 1
                }
            }
        }
    }

    // MARK: - Private

    private func buildScene(in sv: SCNView) {
        let s = Self.makeScene()
        sv.scene = s
        sv.isPlaying = true
        scene = s
    }

    /// The empty stage: black background, the camera looking into the grid and its lights.
    private static func makeScene() -> SCNScene {
        let s = SCNScene()
        s.background.contents = NSColor.black
        let gridCenter = SCNVector3(Float(pipeGridX - 1) / 2, Float(pipeGridY - 1) / 2, Float(pipeGridZ - 1) / 2)

        // Far enough back that the grid's front face just fills a 16:9 screen; the pipes further in look smaller.
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        camera.fieldOfView = 45
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(gridCenter.x, gridCenter.y, gridCenter.z + 22)
        cameraNode.look(at: gridCenter)
        s.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 350
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        s.rootNode.addChildNode(ambientNode)

        // A directional light shines down its node's -z: from above the camera's left shoulder into the grid.
        let dir = SCNLight()
        dir.type = .directional
        dir.intensity = 900
        let dirNode = SCNNode()
        dirNode.light = dir
        dirNode.position = SCNVector3(gridCenter.x - 10, gridCenter.y + 18, gridCenter.z + 25)
        dirNode.look(at: gridCenter)
        s.rootNode.addChildNode(dirNode)
        return s
    }

    private func startPipes() {
        for _ in 0..<Self.pipeCount { activePipes.append(newPipe()) }
    }

    /// A pipe starting in a free cell, in a color none of the growing pipes has.
    private func newPipe() -> Pipe {
        let start = randomFreeCell() ?? GridCell(x: pipeGridX / 2, y: pipeGridY / 2, z: pipeGridZ / 2)
        occupied.insert(start)
        let inUse = activePipes.map(\.color)
        let color = Self.palette.filter { !inUse.contains($0) }.randomElement() ?? Self.palette[0]
        return Pipe(position: start, direction: GridDirection.allCases.randomElement()!, color: color)
    }

    /// Too full to keep growing: the pipes start over on the next tick.
    private var isFull: Bool { Double(occupied.count) / Double(Self.totalCells) > Self.resetFraction }

    private func tick() {
        if isFull { reset(); return }
        for i in activePipes.indices { activePipes[i] = grown(activePipes[i]) }
    }

    /// `pipe` one step further on, now and then around a corner; a new pipe in its place once it is boxed in.
    private func grown(_ pipe: Pipe) -> Pipe {
        let free = GridDirection.allCases.filter { isFree(pipe.position.moved(by: $0)) }
        guard !free.isEmpty else { return newPipe() }
        let turns = free.filter { $0 != pipe.direction }
        let goesStraight = free.contains(pipe.direction) && (turns.isEmpty || Double.random(in: 0..<1) >= Self.turnChance)
        let direction = goesStraight ? pipe.direction : turns.randomElement() ?? pipe.direction
        if direction != pipe.direction { addJoint(at: pipe.position, color: pipe.color) }
        let next = pipe.position.moved(by: direction)
        addSegment(from: pipe.position, to: next, color: pipe.color)
        occupied.insert(next)
        segmentCount += 1
        return Pipe(position: next, direction: direction, color: pipe.color)
    }

    private func isFree(_ cell: GridCell) -> Bool { cell.isValid && !occupied.contains(cell) }

    private func reset() {
        scene?.rootNode.childNodes
            .filter { $0.camera == nil && $0.light == nil }
            .forEach { $0.removeFromParentNode() }
        occupied.removeAll()
        activePipes.removeAll()
        segmentCount = 0
        startPipes()
    }

    private func addSegment(from a: GridCell, to b: GridCell, color: NSColor) {
        guard let scene else { return }
        // Cylinder between centers
        let dx = Float(b.x - a.x), dy = Float(b.y - a.y), dz = Float(b.z - a.z)
        let length = sqrt(dx*dx + dy*dy + dz*dz)
        let cylinder = SCNCylinder(radius: 0.18, height: CGFloat(length))
        cylinder.materials = [Self.material(color)]
        let node = SCNNode(geometry: cylinder)
        let mid = SCNVector3(
            Float(a.x) + dx/2, Float(a.y) + dy/2, Float(a.z) + dz/2
        )
        node.position = mid
        // Orient along the direction
        node.eulerAngles = SCNVector3(
            dy != 0 ? 0 : Float.pi/2,
            dz != 0 ? 0 : (dx > 0 ? Float.pi/2 : -Float.pi/2),
            0
        )
        scene.rootNode.addChildNode(node)
    }

    /// The ball where a pipe turns a corner.
    private func addJoint(at cell: GridCell, color: NSColor) {
        guard let scene else { return }
        let sphere = SCNSphere(radius: 0.26)
        sphere.materials = [Self.material(color)]
        let joint = SCNNode(geometry: sphere)
        joint.position = SCNVector3(Float(cell.x), Float(cell.y), Float(cell.z))
        scene.rootNode.addChildNode(joint)
    }

    private static func material(_ color: NSColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.specular.contents = NSColor.white
        mat.shininess = 60
        return mat
    }

    private func randomFreeCell() -> GridCell? {
        var tries = 0
        while tries < 50 {
            let c = GridCell(x: Int.random(in: 0..<pipeGridX),
                             y: Int.random(in: 0..<pipeGridY),
                             z: Int.random(in: 0..<pipeGridZ))
            if !occupied.contains(c) { return c }
            tries += 1
        }
        return nil
    }
}

// MARK: - Supporting types

/// About 16:9 across, like the screen the pipes fill.
private let pipeGridX = 26, pipeGridY = 15, pipeGridZ = 10

struct GridCell: Hashable {
    let x, y, z: Int
    var isValid: Bool {
        x >= 0 && x < pipeGridX &&
        y >= 0 && y < pipeGridY &&
        z >= 0 && z < pipeGridZ
    }
    func moved(by d: GridDirection) -> GridCell {
        GridCell(x: x + d.dx, y: y + d.dy, z: z + d.dz)
    }
}

enum GridDirection: CaseIterable {
    case posX, negX, posY, negY, posZ, negZ
    var dx: Int { self == .posX ? 1 : self == .negX ? -1 : 0 }
    var dy: Int { self == .posY ? 1 : self == .negY ? -1 : 0 }
    var dz: Int { self == .posZ ? 1 : self == .negZ ? -1 : 0 }
}

struct Pipe {
    var position: GridCell
    var direction: GridDirection
    var color: NSColor
}
