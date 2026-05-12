// GlitchScene.swift
// "Read at 2:14 AM" — SpriteKit Glitch System
//
// Drop-in replacement for the SwiftUI GlitchLayer.
// Mirrors every phase from the original phaseAnimator logic,
// converted to SKAction sequences for better performance and control.
//
// Usage (in ChatRoomView, replace GlitchLayer with):
//   GlitchSceneView(trigger: gameManager.glitchTrigger, level: gameManager.denialLevel)

import SpriteKit
import SwiftUI
import UIKit
import Combine

// MARK: - GlitchNode
// ─────────────────────────────────────────────────────────────────────────────
// A self-contained SKNode that owns all glitch visuals and animation logic.
// Add it to any SKScene; the scene itself stays as a thin host.

final class GlitchNode: SKNode {

    // MARK: Child Nodes

    /// Full-screen white overlay. blendMode .add ≈ SwiftUI's .plusLighter.
    private var whiteFlashNode: SKSpriteNode!

    /// Horizontal red scanline (h:12pt). blendMode .screen matches SwiftUI.
    private var redBarNode: SKSpriteNode!

    /// Horizontal cyan scanline (h:16pt). blendMode .screen matches SwiftUI.
    private var cyanBarNode: SKSpriteNode!
    
    /// Layer semut TV yang selalu bergetar
    private var noiseNode: SKSpriteNode!
    
    private var shadowNode: SKSpriteNode!
        private var crackNode: SKSpriteNode!

    // MARK: Properties

    private let sceneSize: CGSize

    // MARK: Init

    /// - Parameter size: Pass the parent SKScene's `.size` so bar positions are accurate.
    init(size: CGSize) {
        self.sceneSize = size
        super.init()
        buildChildNodes()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init(size:) — coder init not supported.")
    }

    // MARK: - Node Construction

    private func buildChildNodes() {
        // ── White Flash ──────────────────────────────────────────────────────
        // anchorPoint (0,0) so position = .zero covers the full scene bottom-left.
        whiteFlashNode = SKSpriteNode(color: .white, size: sceneSize)
        whiteFlashNode.anchorPoint = .zero          // Bottom-left origin
        whiteFlashNode.position    = .zero
        whiteFlashNode.blendMode   = .add           // Closest SK equivalent to .plusLighter
        whiteFlashNode.alpha       = 0              // Hidden by default
        whiteFlashNode.zPosition   = 10
        addChild(whiteFlashNode)

        // ── Red Scanline ──────────────────────────────────────────────────────
        // Height 12pt, left-anchored so it stretches the full width.
        redBarNode = SKSpriteNode(color: .red,
                                  size: CGSize(width: sceneSize.width, height: 12))
        redBarNode.anchorPoint = CGPoint(x: 0, y: 0.5) // Left edge, vertically centred
        redBarNode.position    = CGPoint(x: 0, y: -50)  // Parked off-screen initially
        redBarNode.blendMode   = .screen
        redBarNode.alpha       = 0
        redBarNode.zPosition   = 9
        addChild(redBarNode)

        // ── Cyan Scanline ──────────────────────────────────────────────────────
        // Height 16pt, same anchor strategy.
        cyanBarNode = SKSpriteNode(color: .cyan,
                                   size: CGSize(width: sceneSize.width, height: 16))
        cyanBarNode.anchorPoint = CGPoint(x: 0, y: 0.5)
        cyanBarNode.position    = CGPoint(x: 0, y: -50)
        cyanBarNode.blendMode   = .screen
        cyanBarNode.alpha       = 0
        cyanBarNode.zPosition   = 9
        addChild(cyanBarNode)
        
        // ── Static Noise (Untuk Background Hitam) ───────────────────────────
                noiseNode = SKSpriteNode(imageNamed: "static_noise.mp3")
                noiseNode.size = CGSize(width: sceneSize.width * 1.5, height: sceneSize.height * 1.5)
                noiseNode.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)
                
                // GUNAKAN .screen atau .add
                // Ini akan membuang warna hitam dari gambar, menyisakan semut putihnya saja
                noiseNode.blendMode = .screen
                
                noiseNode.alpha = 0
                noiseNode.zPosition = 1
                addChild(noiseNode)

                // Animasi "semut" bergetar
                let randomize = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    let dx = CGFloat.random(in: -20...20)
                    let dy = CGFloat.random(in: -20...20)
                    self.noiseNode.position = CGPoint(x: self.sceneSize.width / 2 + dx,
                                                      y: self.sceneSize.height / 2 + dy)
                }
                let wait = SKAction.wait(forDuration: 0.05)
                noiseNode.run(SKAction.repeatForever(SKAction.sequence([randomize, wait])))
        
        // ── 3. Jumpscare Siluet ──────────────────────────────────────────────
                shadowNode = SKSpriteNode(imageNamed: "shadow_face.png")
                // Buat ukurannya sebesar layar
                shadowNode.size = CGSize(width: sceneSize.width, height: sceneSize.height)
                shadowNode.position = CGPoint(x: -sceneSize.width, y: sceneSize.height / 2) // Sembunyikan di luar layar kiri
                shadowNode.blendMode = .multiply // Agar menyatu dengan background secara gelap
                shadowNode.alpha = 0
                shadowNode.zPosition = 8 // Di bawah tombol, tapi di atas chat
                addChild(shadowNode)

                // ── 4. Layar Retak ──────────────────────────────────────────────────
                crackNode = SKSpriteNode(imageNamed: "glass_crack.png")
                crackNode.size = CGSize(width: sceneSize.width, height: sceneSize.height)
                crackNode.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2) // Tepat di tengah
        shadowNode.blendMode = .alpha
                crackNode.alpha = 0
                crackNode.zPosition = 20 // Paling atas! Menutupi segalanya
                addChild(crackNode)
    }

    // MARK: - Public API

    /// Fires the 4-phase glitch sequence. Safe to call while a sequence is already
    /// running — it cancels and restarts cleanly (matching SwiftUI trigger semantics).
    ///
    /// - Parameter level: `"Low"` / `"Medium"` → subtle pass.
    ///                    `"High"` → intense, fast, high-opacity pass.
    func startGlitch(level: String) {
        // Cancel any in-flight sequence and snap visuals back to hidden
        removeAllActions()
        applyReset()

        let isHigh = level == "High"

        // ── Timing ─────────────────────────────────────────────────────────
        // Mirrors `animation: { .linear(duration:) }` from the phase animator.
        let phaseDuration: TimeInterval = isHigh ? 0.05 : 0.07

        // ── Intensity values ────────────────────────────────────────────────
        let shakeX:     CGFloat = isHigh ? 15.0 : 6.0   // Horizontal offset in points
        let flashAlpha: CGFloat = isHigh ? 0.6  : 0.2   // White flash peak opacity

        // ── Y positions for scanlines ───────────────────────────────────────
        // SwiftUI uses top-left origin; SpriteKit uses bottom-left.
        // SwiftUI red  phase 1: offset y = height * 0.2 from top → SK: height * 0.80
        // SwiftUI cyan phase 3: offset y = height * 0.4 from top → SK: height * 0.60
        let redBarY  = sceneSize.height * 0.80
        let cyanBarY = sceneSize.height * 0.60

        // ══════════════════════════════════════════════════════════════════
        // PHASE 1 — Red bar slides in at 20% (from top) + shake RIGHT
        // Mirrors: phase == 1, red bar visible, offset +shakeX
        // ══════════════════════════════════════════════════════════════════
        let phase1 = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                self.position.x            = shakeX   // Shake whole node right
                self.redBarNode.position.y = redBarY
                self.redBarNode.alpha      = 0.5
                self.cyanBarNode.alpha     = 0
                self.whiteFlashNode.alpha  = 0
            },
            SKAction.wait(forDuration: phaseDuration)
        ])

        // ══════════════════════════════════════════════════════════════════
        // PHASE 2 — White flash at peak opacity, no horizontal offset
        // Mirrors: phase == 2, white flash, offset = 0
        // For "High", a rapid micro-stutter is added (two quick x jabs).
        // ══════════════════════════════════════════════════════════════════
        let phase2VisualSetup = SKAction.run { [weak self] in
            guard let self else { return }
            self.position.x           = 0
            self.redBarNode.alpha     = 0
            self.whiteFlashNode.alpha = flashAlpha
        }

        let phase2: SKAction
        if isHigh {
            // Extra micro-shake for "High": jab left → right → centre, all within phase budget
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

        // ══════════════════════════════════════════════════════════════════
        // PHASE 3 — Cyan bar slides in at 40% (from top) + shake LEFT
        // Mirrors: phase == 3, cyan bar visible, offset -shakeX
        // ══════════════════════════════════════════════════════════════════
        let phase3 = SKAction.sequence([
            SKAction.run { [weak self] in
                guard let self else { return }
                self.position.x             = -shakeX   // Shake whole node left
                self.whiteFlashNode.alpha   = 0
                self.redBarNode.alpha       = 0
                self.cyanBarNode.position.y = cyanBarY
                self.cyanBarNode.alpha      = 0.5
            },
            SKAction.wait(forDuration: phaseDuration)
        ])

        // ══════════════════════════════════════════════════════════════════
        // PHASE 4 — Full reset; mirrors the animator returning to phase 0
        // ══════════════════════════════════════════════════════════════════
        let phase4 = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.applyReset()
            },
            SKAction.wait(forDuration: phaseDuration)
        ])

        // Fire the complete sequence once
        run(SKAction.sequence([phase1, phase2, phase3, phase4]))
    }
    
    /// Mengatur ketebalan semut TV berdasarkan Denial Score
        func updateNoise(denialScore: Int) {
            if denialScore > 7 {
                // Makin tinggi skor (contoh: 15), alpha naik. Dibatasi maksimal 0.3 agar chat tetap bisa dibaca.
                let calculatedAlpha = min(0.3, CGFloat(denialScore - 7) * 0.03)
                noiseNode.run(SKAction.fadeAlpha(to: calculatedAlpha, duration: 1.0))
            } else {
                // Hilangkan semut jika denial score turun
                noiseNode.run(SKAction.fadeAlpha(to: 0, duration: 1.0))
            }
        }
    
    /// Meluncurkan bayangan secepat kilat melintasi layar
    /// Meluncurkan bayangan dengan kecepatan yang pas ditambah suara jumpscare
        func triggerShadow() {
            // Reset posisi ke kiri layar
            shadowNode.position = CGPoint(x: -sceneSize.width, y: sceneSize.height / 2)
            
            // Munculkan lebih pekat agar terlihat jelas (dari 0.6 jadi 0.9)
            shadowNode.alpha = 0.9
            
            // 1. Siapkan Suara Jumpscare
            // Pastikan nama dan ekstensinya persis dengan file yang kamu masukkan!
            let playSound = SKAction.playSoundFileNamed("jumpscare.mp3", waitForCompletion: false)
            
            // 2. Perlambat gerakan melintasnya (dari 0.15 detik menjadi 0.4 detik)
            let dashRight = SKAction.moveTo(x: sceneSize.width * 1.5, duration: 0.6)
            
            // 3. Gabungkan suara dan gerakan agar berjalan bersamaan!
            let scareAction = SKAction.group([playSound, dashRight])
            
            // 4. Hilangkan perlahan
            let fadeOut = SKAction.fadeOut(withDuration: 0.2)
            
            // Jalankan aksinya berurutan
            shadowNode.run(SKAction.sequence([scareAction, fadeOut]))
        }
        /// Memecahkan layar secara permanen
    /// Memecahkan layar secara permanen ditambah suara pecahan kaca
        func triggerCrack() {
            // Langsung munculkan gambar kaca retaknya 100%
            crackNode.alpha = 1.0
            
            // 1. Panggil file suara kaca pecah (pastikan namanya sesuai dengan filemu!)
            let playSound = SKAction.playSoundFileNamed("crack_sfx", waitForCompletion: false)
            
            // 2. Beri efek getaran keras sesaat (Visual Shake)
            let shake1 = SKAction.moveBy(x: 15, y: -15, duration: 0.05)
            let shake2 = SKAction.moveBy(x: -15, y: 15, duration: 0.05)
            let visualShake = SKAction.sequence([shake1, shake2])
            
            // 3. Gabungkan Suara dan Getaran agar terjadi bersamaan!
            let smashAction = SKAction.group([playSound, visualShake])
            
            // Jalankan aksinya
            crackNode.run(smashAction)
        }

    // MARK: - Private Helpers

    /// Snaps every visual back to its invisible, neutral state.
    private func applyReset() {
        position.x              = 0
        whiteFlashNode?.alpha   = 0
        redBarNode?.alpha       = 0
        cyanBarNode?.alpha      = 0
    }
}

// MARK: - GlitchScene
// ─────────────────────────────────────────────────────────────────────────────
// A transparent SKScene that acts as the host for GlitchNode.
// Keep this thin — all visual logic lives in GlitchNode.

final class GlitchScene: SKScene {

    // The single child node that owns all glitch effects.
    private var glitchNode: GlitchNode?
    
    func updateNoise(score: Int) {
            glitchNode?.updateNoise(denialScore: score)
        }
    
    func fireShadow() { glitchNode?.triggerShadow() }
        func fireCrack() { glitchNode?.triggerCrack() }

    // MARK: Scene Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)

        // ⚠️  Critical: clear background so it overlays your ChatRoomView
        backgroundColor = .clear

        // `self.size` is now valid — pass it to GlitchNode for correct positioning
        let node = GlitchNode(size: self.size)
        node.position = .zero   // Bottom-left of scene
        addChild(node)
        self.glitchNode = node
    }

    // MARK: - Public API

    /// Call this from SwiftUI whenever the glitch trigger fires.
    /// - Parameter level: `"Low"`, `"Medium"`, or `"High"`
    func startGlitch(level: String) {
        glitchNode?.startGlitch(level: level)
    }
}

// MARK: - GlitchSceneHolder
// ─────────────────────────────────────────────────────────────────────────────
// ObservableObject wrapper so SwiftUI can hold GlitchScene as a @StateObject.
// This guarantees the scene is created once per view lifetime.

@MainActor
final class GlitchSceneHolder: ObservableObject {

    @Published var scene: GlitchScene

    init() {
        // Beri ukuran default bayangan (ukuran rata-rata layar iPhone)
        var screenSize = CGSize(width: 400, height: 900)
        
        // Coba ambil ukuran layar asli dengan cara iOS terbaru
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenSize = windowScene.screen.bounds.size
        }
        
        let s = GlitchScene(size: screenSize)
        s.scaleMode = .resizeFill // Ini akan otomatis menyesuaikan ukuran scene ke layar asli
        self.scene = s
    }
}

// MARK: - GlitchSceneView  ← SwiftUI Integration
// ─────────────────────────────────────────────────────────────────────────────
// A transparent SpriteView overlay.  Drop this as the LAST child in the ZStack
// of your ChatRoomView, exactly where GlitchLayer used to sit.
//
// Example:
//
//   ZStack {
//       ChatRoomView(...)
//       GlitchSceneView(trigger: gameManager.glitchTrigger,
//                       level:   gameManager.denialLevel)
//   }

struct GlitchSceneView: View {

    /// Increment this integer to fire a new glitch sequence.
    /// Mirrors the `trigger: Int` parameter of the old GlitchLayer.
    var trigger: Int

    /// Glitch intensity: `"Low"`, `"Medium"`, or `"High"`.
    /// Mirrors the `level: String` parameter of the old GlitchLayer.
    var level: String
    var denialScore: Int
    var shadowTrigger: Int
        var crackTrigger: Int

    // One scene per view instance, kept alive for the view's lifetime.
    @StateObject private var holder = GlitchSceneHolder()

    var body: some View {
        SpriteView(
            scene:   holder.scene,
            options: [.allowsTransparency]  // ← REQUIRED for clear background
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)   // Pass all touches through to ChatRoomView
        // React to trigger changes the same way phaseAnimator(trigger:) did.
        .onChange(of: trigger) { _, _ in
            holder.scene.startGlitch(level: level)
        }
        .onChange(of: denialScore) { _, newScore in
                    holder.scene.updateNoise(score: newScore)
                }
        .onChange(of: shadowTrigger) { _, _ in
                    holder.scene.fireShadow()
                }
                .onChange(of: crackTrigger) { _, _ in
                    holder.scene.fireCrack()
                }
    }
}
