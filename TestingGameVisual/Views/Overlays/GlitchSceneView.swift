// GlitchSceneView.swift
// "Read at 2:14 AM" — SpriteKit Glitch System

import SpriteKit
import SwiftUI
import UIKit
import Combine

// MARK: - GlitchNode
// ─────────────────────────────────────────────────────────────────────────────

final class GlitchNode: SKNode {

    // MARK: Child Nodes

    private var whiteFlashNode: SKSpriteNode!
    private var redBarNode: SKSpriteNode!
    private var cyanBarNode: SKSpriteNode!
    private var noiseNode: SKSpriteNode!
    private var shadowNode: SKSpriteNode!
    private var crackNode: SKSpriteNode!

    // MARK: Properties

    private let sceneSize: CGSize

    // MARK: Init

    init(size: CGSize) {
        self.sceneSize = size
        super.init()
        buildChildNodes()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Node Construction

    private func buildChildNodes() {

        // ── White Flash ──────────────────────────────────────────────────────
        whiteFlashNode = SKSpriteNode(color: .white, size: sceneSize)
        whiteFlashNode.anchorPoint = .zero
        whiteFlashNode.position    = .zero
        whiteFlashNode.blendMode   = .add
        whiteFlashNode.alpha       = 0
        whiteFlashNode.zPosition   = 10
        addChild(whiteFlashNode)

        // ── Red Scanline ──────────────────────────────────────────────────────
        redBarNode = SKSpriteNode(color: .red,
                                  size: CGSize(width: sceneSize.width, height: 12))
        redBarNode.anchorPoint = CGPoint(x: 0, y: 0.5)
        redBarNode.position    = CGPoint(x: 0, y: -50)
        redBarNode.blendMode   = .screen
        redBarNode.alpha       = 0
        redBarNode.zPosition   = 9
        addChild(redBarNode)

        // ── Cyan Scanline ──────────────────────────────────────────────────────
        cyanBarNode = SKSpriteNode(color: .cyan,
                                   size: CGSize(width: sceneSize.width, height: 16))
        cyanBarNode.anchorPoint = CGPoint(x: 0, y: 0.5)
        cyanBarNode.position    = CGPoint(x: 0, y: -50)
        cyanBarNode.blendMode   = .screen
        cyanBarNode.alpha       = 0
        cyanBarNode.zPosition   = 9
        addChild(cyanBarNode)

        // ── Static Noise ─────────────────────────────────────────────────────
        noiseNode = SKSpriteNode(imageNamed: "static_noise")
        noiseNode.size = CGSize(width: sceneSize.width * 1.5, height: sceneSize.height * 1.5)
        noiseNode.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        noiseNode.blendMode = .screen
        noiseNode.alpha = 0
        noiseNode.zPosition = 1
        addChild(noiseNode)

        // Randomize noise position every 0.05s for static effect
        let randomize = SKAction.run { [weak self] in
            guard let self = self else { return }
            let dx = CGFloat.random(in: -20...20)
            let dy = CGFloat.random(in: -20...20)
            self.noiseNode.position = CGPoint(x: self.sceneSize.width / 2 + dx,
                                              y: self.sceneSize.height / 2 + dy)
        }
        let wait = SKAction.wait(forDuration: 0.05)
        noiseNode.run(SKAction.repeatForever(SKAction.sequence([randomize, wait])))

        // ── Jumpscare Shadow ─────────────────────────────────────────────────
        // Uses .multiply blend so shadowNode renders correctly over the scene.
        shadowNode = SKSpriteNode(imageNamed: "shadow_face")
        shadowNode.size = CGSize(width: sceneSize.width, height: sceneSize.height)
        shadowNode.position = CGPoint(x: -sceneSize.width, y: sceneSize.height / 2)
        shadowNode.blendMode = .multiply
        shadowNode.alpha = 0
        shadowNode.zPosition = 8
        addChild(shadowNode)

        // ── Glass Crack ───────────────────────────────────────────────────────
        // Uses .alpha blend; kept separate from shadowNode intentionally.
        crackNode = SKSpriteNode(imageNamed: "glass_crack")
        crackNode.size = CGSize(width: sceneSize.width, height: sceneSize.height)
        crackNode.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
        crackNode.blendMode = .alpha
        crackNode.alpha = 0
        crackNode.zPosition = 20
        addChild(crackNode)
    }

    // MARK: - Public API

    func startGlitch(level: String) {
        removeAllActions()
        applyReset()

        let isHigh = level == "High"

        let phaseDuration: TimeInterval = isHigh ? 0.05 : 0.07
        let shakeX:     CGFloat = isHigh ? 15.0 : 6.0
        let flashAlpha: CGFloat = isHigh ? 0.6  : 0.2

        let redBarY  = sceneSize.height * 0.80
        let cyanBarY = sceneSize.height * 0.60

        // Phase 1: shake right + red bar
        let phase1 = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                self.position.x            = shakeX
                self.redBarNode.position.y = redBarY
                self.redBarNode.alpha      = 0.5
                self.cyanBarNode.alpha     = 0
                self.whiteFlashNode.alpha  = 0
            },
            SKAction.wait(forDuration: phaseDuration)
        ])

        // Phase 2: white flash (with micro-stutter on high)
        let phase2VisualSetup = SKAction.run { [weak self] in
            guard let self else { return }
            self.position.x           = 0
            self.redBarNode.alpha     = 0
            self.whiteFlashNode.alpha = flashAlpha
        }

        let phase2: SKAction
        if isHigh {
            let jitterDuration = phaseDuration / 4
            let microStutter = SKAction.sequence([
                SKAction.run { [weak self] in self?.position.x = -4 },
                SKAction.wait(forDuration: jitterDuration),
                SKAction.run { [weak self] in self?.position.x =  4 },
                SKAction.wait(forDuration: jitterDuration),
                SKAction.run { [weak self] in self?.position.x =  0 },
                SKAction.wait(forDuration: phaseDuration / 2)
            ])
            phase2 = SKAction.sequence([phase2VisualSetup, microStutter])
        } else {
            phase2 = SKAction.sequence([phase2VisualSetup,
                                        SKAction.wait(forDuration: phaseDuration)])
        }

        // Phase 3: shake left + cyan bar
        let phase3 = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                self.position.x             = -shakeX
                self.whiteFlashNode.alpha   = 0
                self.redBarNode.alpha       = 0
                self.cyanBarNode.position.y = cyanBarY
                self.cyanBarNode.alpha      = 0.5
            },
            SKAction.wait(forDuration: phaseDuration)
        ])

        // Phase 4: reset to neutral
        let phase4 = SKAction.sequence([
            SKAction.run { [weak self] in self?.applyReset() },
            SKAction.wait(forDuration: phaseDuration)
        ])

        run(SKAction.sequence([phase1, phase2, phase3, phase4]))
    }

    func updateNoise(denialScore: Int) {
        if denialScore > 7 {
            let alpha = min(0.3, CGFloat(denialScore - 7) * 0.03)
            noiseNode.run(SKAction.fadeAlpha(to: alpha, duration: 1.0))
        } else {
            noiseNode.run(SKAction.fadeAlpha(to: 0, duration: 1.0))
        }
    }

    func triggerShadow() {
        shadowNode.position = CGPoint(x: -sceneSize.width, y: sceneSize.height / 2)
        shadowNode.alpha = 0.9

        let playSound = SKAction.playSoundFileNamed("jumpscare.mp3", waitForCompletion: false)
        let dashRight = SKAction.moveTo(x: sceneSize.width * 1.5, duration: 0.6)
        let scareAction = SKAction.group([playSound, dashRight])
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)

        shadowNode.run(SKAction.sequence([scareAction, fadeOut]))
    }

    func triggerCrack() {
        crackNode.alpha = 1.0

        let playSound = SKAction.playSoundFileNamed("crack_sfx.mp3", waitForCompletion: false)
        let shake1 = SKAction.moveBy(x: 15, y: -15, duration: 0.05)
        let shake2 = SKAction.moveBy(x: -15, y: 15, duration: 0.05)
        let visualShake = SKAction.sequence([shake1, shake2])
        let smashAction = SKAction.group([playSound, visualShake])

        crackNode.run(smashAction)
    }

    /// Makes the crack visible immediately without animation (e.g. after restoring from save).
    func showStaticCrack() {
        crackNode.alpha = 1.0
    }

    /// Hides the crack overlay (e.g. when restarting the game).
    func hideCrack() {
        crackNode.removeAllActions()
        crackNode.alpha = 0
    }

    /// Applies an instant visual state based on saved score/crack values (called before didMove).
    func applyInstantState(score: Int, crack: Int) {
        if score > 7 {
            noiseNode.alpha = min(0.3, CGFloat(score - 7) * 0.03)
        }
        crackNode.alpha = (crack > 0) ? 1.0 : 0
    }

    // MARK: - Private Helpers

    private func applyReset() {
        position.x              = 0
        whiteFlashNode?.alpha   = 0
        redBarNode?.alpha       = 0
        cyanBarNode?.alpha      = 0
    }
}

// MARK: - GlitchScene
// ─────────────────────────────────────────────────────────────────────────────

final class GlitchScene: SKScene {

    // MARK: Properties

    var initialScore: Int = 0
    var initialCrack: Int = 0

    private var glitchNode: GlitchNode?

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .clear

        let node = GlitchNode(size: self.size)
        node.position = .zero
        addChild(node)
        self.glitchNode = node
        node.applyInstantState(score: initialScore, crack: initialCrack)
    }

    // MARK: Public API

    func startGlitch(level: String) { glitchNode?.startGlitch(level: level) }
    func updateNoise(score: Int)    { glitchNode?.updateNoise(denialScore: score) }
    func fireShadow()               { glitchNode?.triggerShadow() }
    func fireCrack()                { glitchNode?.triggerCrack() }
    func showStaticCrack()          { glitchNode?.showStaticCrack() }
    func hideCrack()                { glitchNode?.hideCrack() }
}

// MARK: - GlitchSceneView
// ─────────────────────────────────────────────────────────────────────────────

struct GlitchSceneView: View {

    var trigger: Int
    var level: String
    var denialScore: Int
    var shadowTrigger: Int
    var crackTrigger: Int

    @StateObject private var holder = GlitchSceneHolder()

    var body: some View {
        SpriteView(
            scene:   holder.scene,
            options: [.allowsTransparency]
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            // Pass initial values to scene before didMove runs,
            // then sync noise and crack overlay immediately.
            holder.scene.initialScore = denialScore
            holder.scene.initialCrack = crackTrigger
            holder.scene.updateNoise(score: denialScore)
            if crackTrigger > 0 { holder.scene.showStaticCrack() }
        }
        .onChange(of: trigger) { _, _ in
            holder.scene.startGlitch(level: level)
        }
        .onChange(of: denialScore) { _, newScore in
            holder.scene.updateNoise(score: newScore)
        }
        .onChange(of: shadowTrigger) { _, _ in
            holder.scene.fireShadow()
        }
        .onChange(of: crackTrigger) { _, newValue in
            if newValue > 0 {
                holder.scene.fireCrack()
            } else {
                // crackTrigger reset to 0 means game restarted — hide crack
                holder.scene.hideCrack()
            }
        }
    }
}

// MARK: - GlitchSceneHolder
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class GlitchSceneHolder: ObservableObject {
    /// Constructed once and never reassigned — `@Published` annotation removed
    /// because it caused needless view diffing for a value that doesn't change.
    let scene: GlitchScene

    init() {
        let s = GlitchScene(size: UIScreen.main.bounds.size)
        s.scaleMode = .resizeFill
        self.scene = s
    }
}
