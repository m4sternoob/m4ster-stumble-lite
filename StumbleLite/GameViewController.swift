//
//  GameViewController.swift
//  StumbleLite
//
//  Owns the SCNView, the SCNScene, the players, and the obstacles.
//  Hosts the round timer, drag input, and the end-of-round flow.
//

import UIKit
import SceneKit

final class GameViewController: UIViewController {

    // MARK: TUNING

    /// Edge-to-edge floor size in SceneKit units.
    static let arenaSize: Float = 20
    static let wallThickness: Float = 0.6
    static let wallHeight: Float = 1.2
    /// Width of the knock-out gap centered in each wall — this is how
    /// players actually get eliminated into the kill zone.
    static let wallGap: Float = 3.0
    static let killZoneY: Float = -8
    static let gravity: Float = -28

    static let roundSeconds: TimeInterval = 60

    // MARK: State

    private var scnView: SCNView!
    private var scene: SCNScene!
    private var players: [Player3D] = []
    private var obstacles: [Obstacle3D] = []
    private var localPlayer: Player3D?
    private var startedAt: TimeInterval = 0
    private var ended = false

    private var timerLabel: UILabel!
    private var aliveCountLabel: UILabel!
    private var joystick: JoystickView!

    // Joystick input (each component in -1...1, set by the joystick).
    private var joystickInput: CGVector = .zero

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupView()
        setupScene()
        setupArena()
        setupObstacles()
        setupPlayers()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: View + HUD

    private func setupView() {
        scnView = SCNView(frame: view.bounds)
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = false
        view.addSubview(scnView)

        // Big timer at the top center.
        timerLabel = UILabel()
        timerLabel.text = "60"
        timerLabel.font = .systemFont(ofSize: 56, weight: .heavy)
        timerLabel.textColor = .white
        timerLabel.textAlignment = .center
        timerLabel.layer.shadowColor = UIColor.black.cgColor
        timerLabel.layer.shadowOffset = .zero
        timerLabel.layer.shadowRadius = 8
        timerLabel.layer.shadowOpacity = 0.8
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)

        // Alive-count chip at the top right.
        aliveCountLabel = UILabel()
        aliveCountLabel.text = "👥 4"
        aliveCountLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        aliveCountLabel.textColor = .white
        aliveCountLabel.backgroundColor = UIColor(white: 0, alpha: 0.45)
        aliveCountLabel.layer.cornerRadius = 10
        aliveCountLabel.layer.masksToBounds = true
        aliveCountLabel.textAlignment = .center
        aliveCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(aliveCountLabel)

        NSLayoutConstraint.activate([
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            timerLabel.widthAnchor.constraint(equalToConstant: 140),
            timerLabel.heightAnchor.constraint(equalToConstant: 80),

            aliveCountLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            aliveCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            aliveCountLabel.widthAnchor.constraint(equalToConstant: 70),
            aliveCountLabel.heightAnchor.constraint(equalToConstant: 36)
        ])

        // ----- Joystick (bottom-left) -----
        joystick = JoystickView()
        joystick.translatesAutoresizingMaskIntoConstraints = false
        joystick.onChange = { [weak self] vector in
            self?.joystickInput = vector
        }
        view.addSubview(joystick)
        NSLayoutConstraint.activate([
            joystick.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            joystick.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -36),
            joystick.widthAnchor.constraint(equalToConstant: 140),
            joystick.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    // MARK: Scene

    private func setupScene() {
        scene = SCNScene()
        scnView.scene = scene
        scnView.delegate = self
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .multisampling4X

        scene.physicsWorld.contactDelegate = self
        scene.physicsWorld.gravity = SCNVector3(0, Self.gravity, 0)

        // Background — gradient using a sky-blue color, looks like sky.
        scene.background.contents = UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 1)

        // ----- Camera -----
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 200
        camera.fieldOfView = 55
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 18, 19)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 4.2, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // ----- Lights -----
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 500
        ambient.color = UIColor(white: 0.97, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1200
        sun.castsShadow = true
        sun.shadowRadius = 5
        sun.shadowSampleCount = 8
        sun.shadowMapSize = CGSize(width: 2048, height: 2048)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 2.6, Float.pi / 6, 0)
        scene.rootNode.addChildNode(sunNode)
    }

    // MARK: Arena

    private func setupArena() {
        let size = Self.arenaSize
        let t = Self.wallThickness
        let h = Self.wallHeight

        // ----- Floor -----
        let floorGeo = SCNBox(
            width: CGFloat(size + 2 * t),
            height: 0.6,
            length: CGFloat(size + 2 * t),
            chamferRadius: 0.15
        )
        floorGeo.materials = [makeMaterial(color: UIColor(red: 0.45, green: 0.30, blue: 0.18, alpha: 1),
                                           roughness: 0.85)]
        let floor = SCNNode(geometry: floorGeo)
        floor.position = SCNVector3(0, -0.3, 0)
        floor.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floor.physicsBody?.categoryBitMask = PhysicsCategory.wall
        floor.physicsBody?.collisionBitMask = PhysicsCategory.player
        scene.rootNode.addChildNode(floor)

        // ----- Walls (each with a centered knock-out gap) -----
        struct WallSpec { let pos: SCNVector3; let size: SCNVector3 }
        let gap = Self.wallGap
        // Segment length, extended by one wall thickness so the
        // segments overlap at the corners instead of leaving a notch.
        let segLen = (size - gap) / 2 + t
        let segOff = gap / 2 + segLen / 2 - t / 2  // segment center offset
        var specs: [WallSpec] = []
        for sign: Float in [-1, 1] {
            let o = sign * segOff
            // East/west walls run along Z.
            specs.append(WallSpec(pos: SCNVector3(-(size / 2 + t / 2), h / 2, o), size: SCNVector3(t, h, segLen)))
            specs.append(WallSpec(pos: SCNVector3( (size / 2 + t / 2), h / 2, o), size: SCNVector3(t, h, segLen)))
            // North/south walls run along X.
            specs.append(WallSpec(pos: SCNVector3(o, h / 2, -(size / 2 + t / 2)), size: SCNVector3(segLen, h, t)))
            specs.append(WallSpec(pos: SCNVector3(o, h / 2,  (size / 2 + t / 2)), size: SCNVector3(segLen, h, t)))
        }
        for s in specs {
            let wall = SCNNode(geometry: SCNBox(
                width: CGFloat(s.size.x),
                height: CGFloat(s.size.y),
                length: CGFloat(s.size.z),
                chamferRadius: 0.05
            ))
            wall.geometry?.materials = [makeMaterial(color: UIColor(red: 0.20, green: 0.20, blue: 0.24, alpha: 1),
                                                    roughness: 0.7)]
            wall.position = s.pos
            wall.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            wall.physicsBody?.categoryBitMask = PhysicsCategory.wall
            wall.physicsBody?.collisionBitMask = PhysicsCategory.player
            scene.rootNode.addChildNode(wall)
        }

        // ----- Kill zone sensor below the arena -----
        let killGeo = SCNPlane(width: CGFloat(size * 3), height: CGFloat(size * 3))
        let kill = SCNNode(geometry: killGeo)
        kill.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        kill.position = SCNVector3(0, Self.killZoneY, 0)
        kill.isHidden = true
        kill.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        kill.physicsBody?.categoryBitMask = PhysicsCategory.killZone
        kill.physicsBody?.collisionBitMask = 0
        kill.physicsBody?.contactTestBitMask = PhysicsCategory.player
        scene.rootNode.addChildNode(kill)
    }

    // MARK: Obstacles

    private func setupObstacles() {
        // Big sweeping bar on the east side
        let bar1 = Obstacle3D(
            kind: .spinningBar(length: 8, radius: 0.25, angularSpeed: 1.4),
            at: SCNVector3(3.5, 1.2, 0)
        )
        scene.rootNode.addChildNode(bar1)
        obstacles.append(bar1)

        // Sliding platform on the west side
        let platform = Obstacle3D(
            kind: .movingPlatform(size: SCNVector3(4, 0.4, 2),
                                  axis: .x,
                                  distance: 5,
                                  periodSeconds: 3.2),
            at: SCNVector3(-3.5, 1.2, 1)
        )
        scene.rootNode.addChildNode(platform)
        obstacles.append(platform)

        // Counter-spinning bar near the back
        let bar2 = Obstacle3D(
            kind: .spinningBar(length: 5, radius: 0.2, angularSpeed: -2.0),
            at: SCNVector3(0, 1.5, -3.5)
        )
        scene.rootNode.addChildNode(bar2)
        obstacles.append(bar2)

        // Fast spinner on the front-right
        let bar3 = Obstacle3D(
            kind: .spinningBar(length: 4, radius: 0.18, angularSpeed: 2.4),
            at: SCNVector3(2.5, 1.5, 3)
        )
        scene.rootNode.addChildNode(bar3)
        obstacles.append(bar3)

        // Sliding platform on the back-left, moving along Z this time
        let platform2 = Obstacle3D(
            kind: .movingPlatform(size: SCNVector3(3, 0.4, 2),
                                  axis: .z,
                                  distance: 4,
                                  periodSeconds: 4.0),
            at: SCNVector3(-2.5, 1.2, -1)
        )
        scene.rootNode.addChildNode(platform2)
        obstacles.append(platform2)
    }

    // MARK: Players

    private func setupPlayers() {
        let palette: [(String, UIColor)] = [
            ("Red",    .systemRed),
            ("Blue",   .systemBlue),
            ("Green",  .systemGreen),
            ("Yellow", .systemYellow)
        ]

        for (i, p) in palette.enumerated() {
            let angle = Float(i) / Float(palette.count) * 2 * .pi
            let pos = SCNVector3(cos(angle) * 4, 1.0, sin(angle) * 4)
            let player = Player3D(id: "P\(i)", displayName: p.0, color: p.1)
            player.position = pos
            scene.rootNode.addChildNode(player)
            players.append(player)
            if i == 0 { localPlayer = player }
        }
    }

    // MARK: Helpers

    private func makeMaterial(color: UIColor, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = 0.0
        m.lightingModel = .physicallyBased
        return m
    }

    private func aliveCount() -> Int {
        players.filter { !$0.isEliminated }.count
    }

    // MARK: Round lifecycle

    fileprivate func endRound(reason: String, winnerName: String?) {
        guard !ended else { return }
        ended = true
        let vc = WinViewController(reason: reason, winnerName: winnerName)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

// MARK: - SCNSceneRendererDelegate

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if startedAt == 0 { startedAt = time }
        let elapsed = time - startedAt

        // Update obstacles (kinematic motion).
        for o in obstacles { o.update(currentTime: time) }

        // Apply joystick input to the local player.
        if let player = localPlayer, !player.isEliminated {
            let mag = sqrt(joystickInput.dx * joystickInput.dx +
                           joystickInput.dy * joystickInput.dy)
            if mag > 0.05 {
                // Joystick dy is negative when dragging up (UIKit
                // coordinates). The camera sits at +Z looking back at
                // the origin, so up-screen is -Z: pass dy through as-is.
                let nx = Float(joystickInput.dx)
                let nz = Float(joystickInput.dy)
                let len = sqrt(nx * nx + nz * nz)
                if len > 0.001 {
                    let ux = nx / len
                    let uz = nz / len
                    player.applyForce(direction: SCNVector3(ux, 0, uz),
                                      scale: Float(min(mag, 1.0)))
                }
            }
        }

        // Cap horizontal speeds.
        for p in players where !p.isEliminated {
            p.capHorizontalSpeed()
        }

        // Timer + HUD.
        let remaining = max(0, Self.roundSeconds - elapsed)
        timerLabel.text = String(Int(ceil(remaining)))
        aliveCountLabel.text = "👥 \(aliveCount())"

        // Time's up → winner is whoever is alive (random if multiple).
        if !ended && remaining <= 0 {
            let alive = players.filter { !$0.isEliminated }
            endRound(reason: "Time's up!",
                     winnerName: alive.randomElement()?.displayName)
        }
    }
}

// MARK: - SCNPhysicsContactDelegate

extension GameViewController: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let a = contact.nodeA
        let b = contact.nodeB
        let catA = a.physicsBody?.categoryBitMask ?? 0
        let catB = b.physicsBody?.categoryBitMask ?? 0

        // Kill zone contact.
        let playerNode: SCNNode?
        if catA == PhysicsCategory.killZone && catB == PhysicsCategory.player {
            playerNode = b
        } else if catB == PhysicsCategory.killZone && catA == PhysicsCategory.player {
            playerNode = a
        } else {
            playerNode = nil
        }
        if let p = playerNode { eliminate(p) }
    }

    fileprivate func eliminate(_ node: SCNNode) {
        guard let player = node as? Player3D, !player.isEliminated else { return }
        player.isEliminated = true
        // Stop interacting with the world immediately — the node still
        // fades out for 0.5s and a "dead" body shouldn't shove anyone.
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.contactTestBitMask = 0
        let fade = SCNAction.sequence([
            SCNAction.fadeOut(duration: 0.5),
            SCNAction.removeFromParentNode()
        ])
        player.runAction(fade)

        let alive = players.filter { !$0.isEliminated }
        if !ended && alive.count <= 1 {
            endRound(reason: "Winner!",
                     winnerName: alive.first?.displayName)
        }
    }
}
