//
//  WinViewController.swift
//  StumbleLite
//
//  End-of-round screen. Shown modally from GameViewController when
//  the timer hits zero or only one player remains.
//

import UIKit

final class WinViewController: UIViewController {

    private let reason: String
    private let winnerName: String?

    init(reason: String, winnerName: String?) {
        self.reason = reason
        self.winnerName = winnerName
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.06, alpha: 0.92)

        let title = UILabel()
        title.text = reason
        title.font = .systemFont(ofSize: 56, weight: .heavy)
        title.textColor = .white
        title.textAlignment = .center

        let subtitle = UILabel()
        if let w = winnerName {
            subtitle.text = "🏆 \(w) wins"
        } else {
            subtitle.text = "Nobody survived"
        }
        subtitle.font = .systemFont(ofSize: 28, weight: .semibold)
        subtitle.textColor = UIColor(white: 0.85, alpha: 1)
        subtitle.textAlignment = .center

        let again = UIButton(type: .system)
        again.setTitle("Play again", for: .normal)
        again.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        again.tintColor = .white
        again.backgroundColor = UIColor.systemGreen
        again.layer.cornerRadius = 14
        again.contentEdgeInsets = UIEdgeInsets(top: 14, left: 28, bottom: 14, right: 28)
        again.addTarget(self, action: #selector(playAgain), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, subtitle, again])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func playAgain() {
        // Easiest reset: rebuild the game VC and present it.
        view.window?.rootViewController = GameViewController()
        dismiss(animated: false)
    }
}
