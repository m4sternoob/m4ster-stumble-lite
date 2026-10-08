//
//  BotBrain.swift
//  StumbleLite
//
//  Simple AI for the non-local players. Each bot re-picks the nearest
//  alive opponent every half second, steers into them to shove them
//  around, and turns back toward the middle when it gets too close to
//  the arena edge so it doesn't throw itself off. A slow wander drift
//  keeps the steering paths from looking like laser lines.
//
//  Bots use the same Player3D.applyForce / capHorizontalSpeed path as
//  the human player, so their movement obeys the same physics.
//

import SceneKit

final class BotBrain {

    // MARK: TUNING

    /// Seconds between target re-picks (jittered per bot).
    static let thinkInterval: Float = 0.5

    /// Force scale relative to Player3D.inputForce. Slightly below 1 so
    /// a committed human player can still out-shove a bot.
    static let aggression: Float = 0.8

    /// How far inside the arena edge (SceneKit units) a bot starts
    /// blending its steering back toward the middle.
    static let edgeMargin: Float = 3.0

    /// Wander drift, radians per second.
    static let wanderRate: Float = 0.9

    /// Size of the wander offset added to the steering direction.
    static let wanderAmount: Float = 0.3

    // MARK: State

    private weak var target: Player3D?
    private var thinkTimer: Float = 0
    private var wanderAngle: Float

    init() {
        // Random starting angle so the bots don't all move alike.
        wanderAngle = Float.random(in: 0...(2 * .pi))
    }

    // MARK: Update

    /// Steer `bot` for one frame. `arenaHalfSize` is half of the floor's
    /// edge-to-edge size (GameViewController.arenaSize / 2).
    func update(bot: Player3D, opponents: [Player3D],
                arenaHalfSize: Float, dt: Float) {
        thinkTimer -= dt
        if thinkTimer <= 0 || target == nil || target?.isEliminated == true {
            target = nearestOpponent(to: bot, from: opponents)
            thinkTimer = Self.thinkInterval * Float.random(in: 0.8...1.2)
        }

        guard let t = target, !t.isEliminated else { return }

        // Chase: direction from the bot to its target, flattened.
        // (SCNVector3 has no arithmetic operators, so this is
        // component-wise.)
        var desired = SCNVector3(t.position.x - bot.position.x,
                                 0,
                                 t.position.z - bot.position.z)
        desired = normalized(desired)

        // Wander: nudge the steering direction with a slowly drifting
        // offset so the paths curve instead of running straight.
        wanderAngle += Self.wanderRate * dt
        desired = normalized(SCNVector3(
            desired.x + cos(wanderAngle) * Self.wanderAmount,
            0,
            desired.z + sin(wanderAngle) * Self.wanderAmount
        ))

        // Edge safety: near the rim, blend steering toward the center
        // with growing urgency so the bot doesn't chase itself off.
        let edgeTurnaround = arenaHalfSize - Self.edgeMargin
        let p = bot.position
        let distFromCenter = sqrt(p.x * p.x + p.z * p.z)
        if distFromCenter > edgeTurnaround {
            let toCenter = normalized(SCNVector3(-p.x, 0, -p.z))
            let urgency = min(1, (distFromCenter - edgeTurnaround) / 2.0)
            desired = normalized(SCNVector3(
                desired.x * (1 - urgency) + toCenter.x * urgency,
                0,
                desired.z * (1 - urgency) + toCenter.z * urgency
            ))
        }

        let len = sqrt(desired.x * desired.x + desired.z * desired.z)
        guard len > 0.001 else { return }
        bot.applyForce(direction: SCNVector3(desired.x / len, 0, desired.z / len),
                       scale: Self.aggression)
    }

    // MARK: Helpers

    private func nearestOpponent(to bot: Player3D,
                                 from opponents: [Player3D]) -> Player3D? {
        let bp = bot.position
        var best: Player3D?
        var bestDist = Float.greatestFiniteMagnitude
        for o in opponents where o !== bot && !o.isEliminated {
            let op = o.position
            let dx = op.x - bp.x
            let dz = op.z - bp.z
            let d = dx * dx + dz * dz
            if d < bestDist {
                bestDist = d
                best = o
            }
        }
        return best
    }

    private func normalized(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        guard len > 0.0001 else { return SCNVector3Zero }
        return SCNVector3(v.x / len, v.y / len, v.z / len)
    }
}
