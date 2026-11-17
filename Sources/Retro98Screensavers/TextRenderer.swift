import AppKit
import SceneKit

/// 3D Text screensaver: "Retro98" extruded and slowly tumbling.
@MainActor
public final class TextRenderer: ScreensaverRenderer {
    private var scnView: SCNView?
    public private(set) var textNode: SCNNode?

    public init() {}

    public func start(in view: NSView) {
        let sv = SCNView(frame: view.bounds)
        sv.autoresizingMask = [.width, .height]
        sv.backgroundColor = .black
        view.addSubview(sv)
        scnView = sv
        buildScene(in: sv)
    }

    public func stop() {
        scnView?.scene?.isPaused = true
        scnView?.removeFromSuperview()
        scnView = nil
        textNode = nil
    }

    public func buildSceneForTesting() {
        let sv = SCNView(frame: .zero)
        buildScene(in: sv)
    }

    var sceneForTesting: SCNScene? { scnView?.scene }

    private func buildScene(in sv: SCNView) {
        let scene = SCNScene()
        scene.background.contents = NSColor.black

        // Camera
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        camera.fieldOfView = 60
        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 0, 20)
        scene.rootNode.addChildNode(camNode)

        // Lights
        let ambient = SCNLight(); ambient.type = .ambient; ambient.intensity = 300
        let ambientNode = SCNNode(); ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let omni = SCNLight(); omni.type = .omni; omni.intensity = 1000
        let omniNode = SCNNode(); omniNode.light = omni; omniNode.position = SCNVector3(10, 10, 10)
        scene.rootNode.addChildNode(omniNode)

        // Text geometry
        let font = NSFont(name: "Arial-BoldMT", size: 5) ?? NSFont.boldSystemFont(ofSize: 5)
        let text = SCNText(string: "Retro98", extrusionDepth: 1.2)
        text.font = font
        text.flatness = 0.1
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0, green: 0.5, blue: 0.5, alpha: 1)
        mat.specular.contents = NSColor.white
        mat.shininess = 80
        text.materials = [mat]

        let node = SCNNode(geometry: text)
        // Center the text
        let (minVec, maxVec) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            (minVec.x + maxVec.x) / 2,
            (minVec.y + maxVec.y) / 2,
            (minVec.z + maxVec.z) / 2
        )
        scene.rootNode.addChildNode(node)
        textNode = node

        // Rotation action
        let rotate = SCNAction.repeatForever(
            SCNAction.rotateBy(x: 0.3, y: 1.5, z: 0.1, duration: 10)
        )
        node.runAction(rotate)

        sv.scene = scene
        sv.isPlaying = true
        scnView = sv
    }
}
