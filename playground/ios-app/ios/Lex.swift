import UIKit

// Container app for the Lex keyboard extension.
//
// iOS requires an app to deliver a keyboard extension. This app does nothing
// beyond explaining how to enable the keyboard; it deliberately does not link
// liblex and does not share state with the extension (no App Group / no
// "Allow Full Access" in this version). All input logic lives in the keyboard
// extension (Keyboard.swift).

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = InstructionsViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

private final class InstructionsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground

        let title_label = UILabel()
        title_label.text = "Lex"
        title_label.font = .systemFont(ofSize: 34, weight: .bold)
        title_label.textAlignment = .center

        let body_label = UILabel()
        body_label.numberOfLines = 0
        body_label.font = .systemFont(ofSize: 17)
        body_label.text = """
            Telex Vietnamese keyboard.

            To enable:
            1. Settings → General → Keyboard → Keyboards.
            2. Add New Keyboard… → Lex.

            To use:
            • In any text field, long-press the globe key and choose Lex.
            • Lex always types Vietnamese (Telex). To type something else,
              switch to another keyboard with the globe key.

            "Allow Full Access" is not required.
            """

        let stack = UIStackView(arrangedSubviews: [title_label, body_label])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)

        let guide = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 40),
        ])
    }
}
