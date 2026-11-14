import RIBs
import UIKit

final class LoggedOutViewController: UIViewController, LoggedOutPresentable, LoggedOutViewControllable, UITextFieldDelegate {

    weak var listener: LoggedOutPresentableListener?

    private let titleLabel = UILabel()
    private let modeControl = UISegmentedControl(items: ["Log in", "Sign up"])
    private let nameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let errorLabel = UILabel()
    private let submitButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        buildLayout()
    }

    func render(_ vm: LoggedOutViewModel) {
        loadViewIfNeeded()
        modeControl.selectedSegmentIndex = vm.mode == .login ? 0 : 1
        nameField.isHidden = !vm.showsNameField
        passwordField.textContentType = vm.mode == .login ? .password : .newPassword
        errorLabel.text = vm.errorMessage
        errorLabel.isHidden = vm.errorMessage == nil
        hintLabel.isHidden = vm.mode != .login
        var config = submitButton.configuration ?? .filled()
        config.title = vm.isLoading ? "Please wait…" : vm.submitTitle
        submitButton.configuration = config
        [submitButton, modeControl, nameField, emailField, passwordField].forEach { ($0 as UIControl).isEnabled = !vm.isLoading }
        vm.isLoading ? spinner.startAnimating() : spinner.stopAnimating()
    }

    @objc private func modeChanged() {
        listener?.didSelect(mode: modeControl.selectedSegmentIndex == 0 ? .login : .signUp)
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        listener?.didTapSubmit(name: nameField.text ?? "", email: emailField.text ?? "", password: passwordField.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField: emailField.becomeFirstResponder()
        case emailField: passwordField.becomeFirstResponder()
        default: submitTapped()
        }
        return true
    }

    private func buildLayout() {
        titleLabel.text = "RibRoomba"
        titleLabel.font = .systemFont(ofSize: 36, weight: .bold)
        titleLabel.textAlignment = .center

        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        configure(nameField, placeholder: "Name", content: .name, keyboard: .default, returnKey: .next)
        configure(emailField, placeholder: "Email", content: .emailAddress, keyboard: .emailAddress, returnKey: .next)
        configure(passwordField, placeholder: "Password", content: .password, keyboard: .default, returnKey: .go)
        passwordField.isSecureTextEntry = true

        errorLabel.textColor = .systemRed
        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        var config = UIButton.Configuration.filled()
        config.title = "Log in"
        config.buttonSize = .large
        config.cornerStyle = .large
        submitButton.configuration = config
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)

        hintLabel.text = "Demo account: demo@ribroomba.app / roomba123"
        hintLabel.font = .preferredFont(forTextStyle: .caption1)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, modeControl, nameField, emailField, passwordField,
                                                   errorLabel, submitButton, spinner, hintLabel])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(28, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    private func configure(_ field: UITextField, placeholder: String, content: UITextContentType,
                           keyboard: UIKeyboardType, returnKey: UIReturnKeyType) {
        field.placeholder = placeholder
        field.textContentType = content
        field.keyboardType = keyboard
        field.returnKeyType = returnKey
        field.autocapitalizationType = content == .name ? .words : .none
        field.autocorrectionType = .no
        field.borderStyle = .roundedRect
        field.backgroundColor = .secondarySystemGroupedBackground
        field.delegate = self
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
}
