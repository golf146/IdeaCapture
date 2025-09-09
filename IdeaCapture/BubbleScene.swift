import SpriteKit
import SwiftUI
import CoreMotion

enum BubbleMode: String, Codable, CaseIterable {
    case dvd
    case gravity
}

class BubbleScene: SKScene {
    private var bubbleNodes: [SKShapeNode] = []
    private var bubbleTexts: [String] = []

    private var draggingNode: SKShapeNode?
    private var dragOffset: CGPoint = .zero

    @AppStorage("bubbleMode") private var bubbleMode: BubbleMode = .dvd

    private let motionManager = CMMotionManager()
    private let gravityStrength: Double = 9.8

    func setBubbleTexts(_ texts: [String]) {
        // 如果内容一样就不重建
        guard texts != bubbleTexts else { return }
        bubbleTexts = texts
        removeAllChildren()
        bubbleNodes.removeAll()

        if size.width > 0 && size.height > 0 {
            createBubbles()
        } else {
            // 延迟一点点，确保 SpriteView 初始化完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.createBubbles()
            }
        }
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsBody?.friction = 0
        applyModePhysics()
    }

    override func willMove(from view: SKView) {
        stopMotion()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsBody?.friction = 0
    }

    private func applyModePhysics() {
        switch bubbleMode {
        case .dvd:
            physicsWorld.gravity = .zero
            stopMotion()
        case .gravity:
            startMotionIfNeeded()
        }
    }

    private func startMotionIfNeeded() {
        guard bubbleMode == .gravity else { return }

        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let m = motion else { return }

                let g = m.gravity
                let dx = g.x * self.gravityStrength
                let dy = g.y * self.gravityStrength
                self.physicsWorld.gravity = CGVector(dx: dx, dy: dy)

                let acc = m.userAcceleration
                let impulse = CGVector(dx: acc.x * 50, dy: acc.y * 50)
                for node in self.bubbleNodes {
                    node.physicsBody?.applyImpulse(impulse)
                }
            }
        } else if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1.0 / 60.0
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let a = data?.acceleration else { return }
                let dx = a.x * self.gravityStrength
                let dy = -a.y * self.gravityStrength
                self.physicsWorld.gravity = CGVector(dx: dx, dy: dy)
            }
        }
    }

    private func stopMotion() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
    }

    private func createBubbles() {
        guard size.width > 0 && size.height > 0 else { return }
        for text in bubbleTexts {
            let bubble = makeBubble(for: text)
            addChild(bubble)
            bubbleNodes.append(bubble)
        }
    }

    // MARK: - 拖动气泡
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard draggingNode == nil, let touch = touches.first else { return }
        let location = touch.location(in: self)
        if let node = nodes(at: location).first(where: { $0 is SKShapeNode && $0.physicsBody != nil }) as? SKShapeNode {
            draggingNode = node
            dragOffset = CGPoint(x: node.position.x - location.x, y: node.position.y - location.y)
            node.physicsBody?.isDynamic = false
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let node = draggingNode, let touch = touches.first else { return }
        var newPos = touch.location(in: self)
        newPos.x += dragOffset.x
        newPos.y += dragOffset.y
        let r = node.frame.width / 2
        newPos.x = max(r, min(size.width - r, newPos.x))
        newPos.y = max(r, min(size.height - r, newPos.y))
        node.position = newPos
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endDrag()
    }

    private func endDrag() {
        draggingNode?.physicsBody?.isDynamic = true
        draggingNode = nil
    }
}

// 补齐 ContentView 期望的接口
extension BubbleScene {
    func reloadConfig() {
        applyModePhysics()
        for node in children {
            guard let body = node.physicsBody else { continue }
            switch bubbleMode {
            case .dvd:
                body.affectedByGravity = false
                body.linearDamping = 0
                if body.velocity.dx == 0 && body.velocity.dy == 0 {
                    body.velocity = CGVector(dx: CGFloat.random(in: -100...100),
                                             dy: CGFloat.random(in: -100...100))
                }
            case .gravity:
                body.affectedByGravity = true
                body.linearDamping = 0.8
            }
        }
    }

    func rebuild(from texts: [String]) {
        setBubbleTexts(texts)
    }

    func addBubble(text: String, persistent: Bool) {
        let node = makeBubble(for: text)
        addChild(node)
        bubbleNodes.append(node)
    }

    private func makeBubble(for text: String) -> SKShapeNode {
        let maxRadius: CGFloat = 70
        let minRadius: CGFloat = 40
        let lengthFactor = max(0.5, 1.0 - CGFloat(text.count) / 30.0)
        let radius = max(minRadius, min(maxRadius, maxRadius * lengthFactor))

        let bubble = SKShapeNode(circleOfRadius: radius)
        bubble.fillColor = .white.withAlphaComponent(0.3)
        bubble.strokeColor = .clear

        // 安全边距调整（离边框只有 8pt）
        let margin: CGFloat = 1
        let safeX = CGFloat.random(in: radius + margin...(size.width - radius - margin))
        let safeY = CGFloat.random(in: radius + margin...(size.height - radius - margin))
        bubble.position = CGPoint(x: safeX, y: safeY)

        let label = SKLabelNode(text: text)
        let baseFontSize: CGFloat = 22
        let adjustedFontSize = min(baseFontSize * lengthFactor, radius * 0.8)
        label.fontSize = adjustedFontSize
        label.fontName = ["HelveticaNeue-Bold", "Courier-Bold", "Avenir-Black", "ChalkboardSE-Bold"].randomElement()!
        label.fontColor = [UIColor.black, UIColor.blue, UIColor.red, UIColor.purple, UIColor.orange].randomElement()!
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        bubble.addChild(label)

        bubble.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        bubble.physicsBody?.restitution = 1
        bubble.physicsBody?.friction = 0
        bubble.physicsBody?.allowsRotation = false

        switch bubbleMode {
        case .dvd:
            bubble.physicsBody?.affectedByGravity = false
            bubble.physicsBody?.linearDamping = 0
            let dx = CGFloat.random(in: -100...100)
            let dy = CGFloat.random(in: -100...100)
            bubble.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
        case .gravity:
            bubble.physicsBody?.affectedByGravity = true
            bubble.physicsBody?.linearDamping = 0.8
        }
        return bubble
    }
}


#if DEBUG
import SwiftUI

struct BubbleScenePreview: View {
    var scene: BubbleScene {
        let scene = BubbleScene(size: CGSize(width: 300, height: 500))
        scene.scaleMode = .resizeFill
        scene.setBubbleTexts([
            "预览1", "Hello", "SwiftUI", "SpriteKit", "测试气泡"
        ])
        return scene
    }

    var body: some View {
        SpriteView(scene: scene)
            .frame(width: 400, height: 800)
            .background(Color.black.opacity(0.1))
            .previewLayout(.sizeThatFits)
    }
}

#Preview {
    BubbleScenePreview()
}
#endif
