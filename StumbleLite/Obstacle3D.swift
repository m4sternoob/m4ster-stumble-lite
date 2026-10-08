//
//  Obstacle3D.swift
//  StumbleLite
//
//  Animated obstacles drawn from SCN primitives. Two kinds:
//
//    - .movingPlatform: slides back and forth along X or Z.
//    - .spinningBar:    rotates around its center (used as a sweeper).
//
//  Both are physics static (kinematic — driven manually each frame).
//

import SceneKit
import UIKit

final class Obstacle3D: SCNNode {

    enum Kind {
        /// Slides back and forth.
        /// - Parameter size: box size.
        /// - Parameter axis: axis of motion.
        /// - Parameter distance: half-range of motion in scene units.
        /// - Parameter periodSeconds: time for one full cycle.
        case movingPlatform(size: SCNVector3, axis: Axis, distance: Float, periodSeconds: TimeInterval)

        /// Spins in place.
        /// - Parameter length: bar length along X.
        /// - Parameter radius: bar radius.
        /// - Parameter angularSpeed: radians per second. Sign = direction.
        case spinningBar(length: Float, radius: Float, angularSpeed: Float)

        enum Axis { case x, z }
    }

    let kind: Kind
    private let origin: SCNVector3
    private var elapsed: TimeInterval = 0
    private var lastTime: TimeInterval = -1

    init(kind: Kind, at origin: SCNVector3) {
        self.kind = kind
        self.origin = origin
        super.init()
        self.position = origin
        buildVisual()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Build

    private func buildVisual() {
        switch kind {
        case .movingPlatform(let size, _, _, _):
            let geo = SCNBox(width: CGFloat(size.x),
                             height: CGFloat(size.y),
                             length: CGFloat(size.z),
                             chamferRadius: 0.08)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor(red: 0.95, green: 0.75, blue: 0.30, alpha: 1)
            mat.roughness.contents = 0.7
            mat.lightingModel = .physicallyBased
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3Zero
            attachPhysics(to: node, shape: geo)
            addChildNode(node)

        case .spinningBar(let length, let radius, _):
            // Bar along X by default
            let geo = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
            geo.materials = {
                let m = SCNMaterial()
                m.diffuse.contents = UIColor.systemRed
                m.roughness.contents = 0.5
                m.lightingModel = .physicallyBased
                return [m]
            }()
            let node = SCNNode(geometry: geo)
            // Cylinder's axis is Y; rotate so the long axis becomes X.
            node.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
            attachPhysics(to: node, shape: geo)
            addChildNode(node)
        }
    }

    private func attachPhysics(to node: SCNNode, shape geometry: SCNGeometry) {
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        body.categoryBitMask = PhysicsCategory.obstacle
        body.collisionBitMask = PhysicsCategory.player
        body.contactTestBitMask = 0
        node.physicsBody = body
    }

    // MARK: Update

    func update(currentTime: TimeInterval) {
        // Real frame delta, not a fixed 1/60 — obstacle speed stays
        // correct on 120Hz displays and under frame drops.
        let dt: TimeInterval
        if lastTime < 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(currentTime - lastTime, 0.1)
        }
        lastTime = currentTime
        elapsed += dt

        switch kind {
        case .movingPlatform(_, let axis, let distance, let period):
            // Triangle wave on the period. 0..1..0 over `period`.
            let phase = elapsed.truncatingRemainder(dividingBy: period) / period
            let tri = phase < 0.5 ? phase * 2 : (1 - phase) * 2
            let offset = Float((tri - 0.5) * 2) * distance  // -distance..+distance

            var p = origin
            switch axis {
            case .x: p.x += offset
            case .z: p.z += offset
            }
            position = p

        case .spinningBar(_, _, let angularSpeed):
            // Apply rotation around Y (world-up) since we already
            // rotated the bar onto its side. SCNNode doesn't expose a
            // simple "add rotation", so accumulate via eulerAngles.
            eulerAngles = SCNVector3(eulerAngles.x,
                                     eulerAngles.y + angularSpeed * Float(dt),
                                     eulerAngles.z)
        }
    }
}
