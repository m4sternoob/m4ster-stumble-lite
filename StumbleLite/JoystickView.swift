//
//  JoystickView.swift
//  StumbleLite
//
//  Virtual joystick for the local player. Lives in the bottom-left of
//  the screen as a transparent UIView. Reports a normalized
//  `CGVector` (each component in -1...1) to its `onChange` callback.
//
//  Visuals: a soft black ring with a white knob that follows the
//  finger. Resets to center when released.
//

import UIKit

final class JoystickView: UIView {

    // MARK: - Public

    /// Called whenever the stick's normalized direction changes
    /// (including back to zero on release).
    var onChange: ((CGVector) -> Void)?

    // MARK: - Private

    private let baseRadius: CGFloat = 70
    private let knobRadius: CGFloat = 32
    private let knob: UIView
    private var activeTouch: UITouch?

    // MARK: - Init

    init() {
        self.knob = UIView(frame: CGRect(x: 0, y: 0,
                                          width: knobRadius * 2,
                                          height: knobRadius * 2))
        super.init(frame: CGRect(x: 0, y: 0,
                                 width: baseRadius * 2,
                                 height: baseRadius * 2))
        setUp()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        // The view itself is the "ring" — semi-transparent black with
        // a white border.
        backgroundColor = UIColor(white: 0, alpha: 0.28)
        layer.cornerRadius = baseRadius
        layer.borderColor = UIColor(white: 1, alpha: 0.6).cgColor
        layer.borderWidth = 2

        // Knob (white circle).
        knob.backgroundColor = UIColor(white: 1, alpha: 0.85)
        knob.layer.cornerRadius = knobRadius
        knob.center = CGPoint(x: baseRadius, y: baseRadius)
        knob.isUserInteractionEnabled = false
        addSubview(knob)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-center the knob if the view is resized.
        knob.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        update(with: touch)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch === activeTouch else { return }
        update(with: touch)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch === activeTouch else { return }
        activeTouch = nil
        recenter()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouch = nil
        recenter()
    }

    // MARK: - Helpers

    private func update(with touch: UITouch) {
        let p = touch.location(in: self)
        let cx = bounds.midX
        let cy = bounds.midY
        let dx = p.x - cx
        let dy = p.y - cy

        // Clamp the knob inside the ring.
        let maxOffset = baseRadius - knobRadius
        let dist = sqrt(dx * dx + dy * dy)
        let (clampedX, clampedY, normalizedMag): (CGFloat, CGFloat, CGFloat) = {
            if dist <= maxOffset {
                return (dx, dy, dist / maxOffset)
            } else {
                let scale = maxOffset / max(dist, 0.0001)
                return (dx * scale, dy * scale, 1.0)
            }
        }()

        knob.center = CGPoint(x: cx + clampedX, y: cy + clampedY)

        // Report to GameViewController. dx is left/right, dy is up/down.
        // In the scene: dragging up (dy negative) = move forward (negative Z).
        onChange?(CGVector(dx: clampedX / maxOffset, dy: clampedY / maxOffset))
    }

    private func recenter() {
        UIView.animate(withDuration: 0.12, delay: 0,
                       options: [.beginFromCurrentState]) {
            self.knob.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        }
        onChange?(.zero)
    }
}
