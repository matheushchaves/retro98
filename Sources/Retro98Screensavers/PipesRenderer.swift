import AppKit
import SceneKit

/// 3D Pipes screensaver: colored pipes grow through a 3D grid using SceneKit.
@MainActor
public final class PipesRenderer: ScreensaverRenderer {
    // MARK: - Grid
    static let totalCells = pipeGridX * pipeGridY * pipeGridZ
    static let resetFraction = 0.75

    private var occupied = Set<GridCell>()
    private var activePipes: [Pipe] = []
    private var scene: SCNScene?
    private var scnView: SCNView?
    private var timer: Timer?

    // MARK: - Test seams
    public private(set) var segmentCount = 0
    public private(set) var activePipeIndex = 0

    public init() {}

    public func start(in view: NSView) {
        let sv = SCNView(frame: view.bounds)
        sv.autoresizingMask = [.width, .height]
        sv.backgroundColor = .black
        sv.antialiasingMode = .multisampling4X
        view.addSubview(sv)
        scnView = sv
        buildScene(in: sv)
        startPipe()
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
        scene = SCNScene()
        occupied.removeAll()
        activePipes.removeAll()
        segmentCount = 0
        startPipe()
    }

    func tickForTesting() { tick() }

    func blockCurrentPipeForTesting() {
        guard !activePipes.isEmpty else { return }
        let pos = activePipes[activePipeIndex].position
        for d in GridDirection.allCases {
            let n = pos.moved(by: d)
            if n.isValid { occupied.insert(n) }
        }
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
        let s = SCNScene()
        s.background.contents = NSColor.black

        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        camera.fieldOfView = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(10, 7.5, 28)
        cameraNode.look(at: SCNVector3(10, 7.5, 5))
        s.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 50
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        s.rootNode.addChildNode(ambientNode)

        let dir = SCNLight()
        dir.type = .directional
        dir.intensity = 100
        let dirNode = SCNNode()
        dirNode.light = dir
        dirNode.position = SCNVector3(10, 20, 20)
        s.rootNode.addChildNode(dirNode)

        sv.scene = s
        sv.isPlaying = true
        scene = s
    }

    private func startPipe() {
        let start = randomFreeCell() ?? GridCell(x: 10, y: 7, z: 5)
        occupied.insert(start)
        let pipe = Pipe(position: start, direction: GridDirection.allCases.randomElement()!, color: randomColor())
        activePipes.append(pipe)
        activePipeIndex = activePipes.count - 1
    }

    private func tick() {
        guard !activePipes.isEmpty else { startPipe(); return }

        // Reset when grid is too full
        if Double(occupied.count) / Double(Self.totalCells) > Self.resetFraction {
            reset(); return
        }

        var pipe = activePipes[activePipeIndex]
        let next = pipe.position.moved(by: pipe.direction)

        if next.isValid && !occupied.contains(next) {
            addSegment(from: pipe.position, to: next, color: pipe.color)
            occupied.insert(next)
            pipe.position = next
            activePipes[activePipeIndex] = pipe
            segmentCount += 1
        } else {
            // Try a new direction
            let free = GridDirection.allCases.filter { d in
                let n = pipe.position.moved(by: d)
                return n.isValid && !occupied.contains(n)
            }
            if let newDir = free.randomElement() {
                pipe.direction = newDir
                activePipes[activePipeIndex] = pipe
            } else {
                // Start a new pipe
                if activePipes.count < 8 { startPipe() } else { activePipeIndex = Int.random(in: 0..<activePipes.count) }
            }
        }
    }

    private func reset() {
        scene?.rootNode.childNodes
            .filter { $0.camera == nil && $0.light == nil }
            .forEach { $0.removeFromParentNode() }
        occupied.removeAll()
        activePipes.removeAll()
        segmentCount = 0
        startPipe()
    }

    private func addSegment(from a: GridCell, to b: GridCell, color: NSColor) {
        guard let scene else { return }
        // Cylinder between centers
        let dx = Float(b.x - a.x), dy = Float(b.y - a.y), dz = Float(b.z - a.z)
        let length = sqrt(dx*dx + dy*dy + dz*dz)
        let cylinder = SCNCylinder(radius: 0.15, height: CGFloat(length))
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.specular.contents = NSColor.white
        mat.shininess = 60
        cylinder.materials = [mat]
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

        // Joint sphere
        let sphere = SCNSphere(radius: 0.2)
        sphere.materials = [mat]
        let joint = SCNNode(geometry: sphere)
        joint.position = SCNVector3(Float(b.x), Float(b.y), Float(b.z))
        scene.rootNode.addChildNode(joint)
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

    private func randomColor() -> NSColor {
        let colors: [NSColor] = [.red, .yellow, .green, .blue, .cyan, .magenta, .white, .orange,
                                  NSColor(red: 1, green: 0.5, blue: 0, alpha: 1)]
        return colors.randomElement()!
    }
}

// MARK: - Supporting types

private let pipeGridX = 20, pipeGridY = 15, pipeGridZ = 10

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
