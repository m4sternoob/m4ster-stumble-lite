//
//  Player3D.swift
//  StumbleLite
//
//  Low-poly humanoid: capsule body + sphere head + two dot eyes.
//  Drawn entirely with SCN primitives so we don't need external model
//  files. To swap in a real character model, replace buildCharacter()
//  with `SCNReferenceNode(url:)` or a hand-loaded SCNNode.
//

import SceneKit
import UIKit

final class Player3D: SCNNode {

    // MARK: Identity

    let id: String
    let displayName: String
    let color: UIColor

    // MARK: State

    var isEliminated: Bool = false

    // MARK: TUNING

    /// Physics body radius. Smaller than the visual capsule so the
    /// capsule can fit inside the arena before the body intersects a
    /// wall.
    static let bodyRadius: Float = 0.4
    static let bodyMass: Float = 1.0
    static let bodyFriction: Float = 0.35
    static let bodyRestitution: Float = 0.45
    static let linearDamping: Float = 1.2
    static let angularDamping: Float = 1.5

    /// Per-frame force cap when applying drag input.
    static let inputForce: Float = 14.0

    /// Cap on horizontal speed (m/s-ish, in SceneKit units).
    static let maxHorizontalSpeed: Float = 9.0

    // MARK: Init

    init(id: String, displayName: String, color: UIColor) {
        self.id = id
        self.displayName = displayName
        self.color = color
        super.init()
        buildCharacter()
        configurePhysics()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Build

    private func buildCharacter() {
        // ----- Material -----
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = color
        bodyMat.roughness.contents = 0.6
        bodyMat.metalness.contents = 0.0
        bodyMat.lightingModel = .physicallyBased

        let eyeMat = SCNMaterial()
        eyeMat.diffuse.contents = UIColor.black
        eyeMat.lightingModel = .constant

        // ----- Body: capsule -----
        let bodyGeo = SCNCapsule(capRadius: 0.35, height: 0.9)
        bodyGeo.materials = [bodyMat]
        let bodyNode = SCNNode(geometry: bodyGeo)
        bodyNode.position = SCNVector3(0, 0.45 + 0.35, 0)  // capsule center
        addChildNode(bodyNode)

        // ----- Head: sphere -----
        let headGeo = SCNSphere(radius: 0.26)
        headGeo.materials = [bodyMat]
        let headNode = SCNNode(geometry: headGeo)
        headNode.position = SCNVector3(0, 0.45 + 0.9 + 0.25, 0)
        addChildNode(headNode)

        // ----- Eyes: two black spheres stuck on the head's +Z face -----
        let eyeGeo = SCNSphere(radius: 0.06)
        eyeGeo.materials = [eyeMat]
        let leftEye = SCNNode(geometry: eyeGeo)
        leftEye.position = SCNVector3(-0.1, 0.05, 0.22)
        headNode.addChildNode(leftEye)
        let rightEye = SCNNode(geometry: eyeGeo)
        rightEye.position = SCNVector3(0.1, 0.05, 0.22)
        headNode.addChildNode(rightEye)
    }

    private func configurePhysics() {
        // Physics shape: a sphere — fast, stable, good enough for this size.
        let shape = SCNPhysicsShape(
            geometry: SCNSphere(radius: CGFloat(Player3D.bodyRadius)),
            options: nil
        )
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = CGFloat(Player3D.bodyMass)
        body.friction = CGFloat(Player3D.bodyFriction)
        body.restitution = CGFloat(Player3D.bodyRestitution)
        body.damping = CGFloat(Player3D.linearDamping)
        body.angularDamping = CGFloat(Player3D.angularDamping)
        body.allowsResting = false

        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.wall
            | PhysicsCategory.obstacle
            | PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.killZone

        self.physicsBody = body
    }

    // MARK: Gameplay

    /// Apply a force in world space. Caller passes a *direction*; the
    /// magnitude is the input force scalar. Use the scene renderer
    /// to call this every frame while input is held.
    func applyForce(direction: SCNVector3, scale: Float = 1.0) {
        guard let body = physicsBody else { return }
        let s = Player3D.inputForce * scale
        body.applyForce(SCNVector3(direction.x * s,
                                   direction.y * s,
                                   direction.z * s),
                        asImpulse: false)
    }

    /// Clamp horizontal velocity so a held drag can't launch a player
    /// past the walls fast enough to tunnel through them.
    func capHorizontalSpeed() {
        guard let body = physicsBody else { return }
        let v = body.velocity
        let speed = sqrt(v.x * v.x + v.z * v.z)
        if speed > Player3D.maxHorizontalSpeed {
            let scale = Player3D.maxHorizontalSpeed / speed
            body.velocity = SCNVector3(v.x * scale, v.y, v.z * scale)
        }
    }

}
