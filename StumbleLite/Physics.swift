//
//  Physics.swift
//  StumbleLite
//
//  Bitmask constants for the SceneKit physics world. Single source of
//  truth — every physics body in the project references these.
//
//  SceneKit's categoryBitMask / collisionBitMask / contactTestBitMask
//  are all `Int` on every platform, so we use Int here.
//

import Foundation

enum PhysicsCategory {
    static let player:   Int = 1 << 0   // 1
    static let wall:     Int = 1 << 1   // 2 — floor, arena edges
    static let obstacle: Int = 1 << 2   // 4 — moving platforms, spinning bars
    static let killZone: Int = 1 << 3   // 8 — sensor below the arena
}
