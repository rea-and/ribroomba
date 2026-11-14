import RIBs
import UIKit

/// Passive view: renders `HomeViewModel`, forwards taps. No business decisions.
final class HomeViewController: UIViewController, HomePresentable, HomeViewControllable {

    weak var listener: HomePresentableListener?

    private let connectionLabel = UILabel()
    private let reconnectButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let batteryLabel = UILabel()
    private let batteryBar = UIProgressView(progressViewStyle: .bar)
    private let binLabel = UILabel()
    private let binBar = UIProgressView(progressViewStyle: .bar)
    private let modeControl = UISegmentedControl(items: CleaningMode.allCases.map(\.displayName))
    private let primaryButton = UIButton(type: .system)
    private let dockButton = UIButton(type: .system)
    private let emptyBinButton = UIButton(type: .system)
    private var primaryAction: HomeViewModel.PrimaryAction = .none

    init() {
        super.init(nibName: nil, bundle: nil)
        title = "Home"
        tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house.fill"), tag: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        buildLayout()
    }

    // MARK: - HomePresentable

    func render(_ vm: HomeViewModel) {
        loadViewIfNeeded()
        connectionLabel.text = "● " + vm.connectionText
        connectionLabel.textColor = vm.isConnected ? .systemGreen : .systemOrange
        reconnectButton.isHidden = !vm.canReconnect
        statusLabel.text = vm.statusTitle
        detailLabel.text = vm.statusDetail
        batteryLabel.text = vm.batteryText
        batteryBar.progress = vm.batteryProgress
        batteryBar.progressTintColor = vm.batteryProgress <= 0.2 ? .systemRed : .systemGreen
        binLabel.text = vm.binText
        binBar.progress = vm.binProgress
        binBar.progressTintColor = vm.binProgress >= 0.9 ? .systemRed : .systemBlue
        primaryAction = vm.primaryAction
        switch vm.primaryAction {
        case .start: primaryButton.setTitle("Start cleaning", for: .normal)
        case .pause: primaryButton.setTitle("Pause", for: .normal)
        case .resume: primaryButton.setTitle("Resume", for: .normal)
        case .none: break
        }
        primaryButton.isHidden = vm.primaryAction == .none
        modeControl.isEnabled = vm.primaryAction == .start
        dockButton.isEnabled = vm.canDock
        emptyBinButton.isEnabled = vm.canEmptyBin
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: "Robot", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        // Avoid stacking alerts if several errors arrive back to back.
        guard presentedViewController == nil, viewIfLoaded?.window != nil else { return }
        present(alert, animated: true)
    }

    // MARK: - Actions

    @objc private func primaryTapped() {
        switch primaryAction {
        case .start: listener?.didTapStart(mode: CleaningMode.allCases[modeControl.selectedSegmentIndex])
        case .pause: listener?.didTapPause()
        case .resume: listener?.didTapResume()
        case .none: break
        }
    }

    @objc private func dockTapped() { listener?.didTapDock() }
    @objc private func emptyBinTapped() { listener?.didTapEmptyBin() }
    @objc private func reconnectTapped() { listener?.didTapReconnect() }

    // MARK: - Layout

    private func buildLayout() {
        connectionLabel.font = .preferredFont(forTextStyle: .footnote)
        reconnectButton.setTitle("Reconnect", for: .normal)
        reconnectButton.addTarget(self, action: #selector(reconnectTapped), for: .touchUpInside)
        let connectionRow = UIStackView(arrangedSubviews: [connectionLabel, UIView(), reconnectButton])

        statusLabel.font = .systemFont(ofSize: 34, weight: .bold)
        statusLabel.adjustsFontSizeToFitWidth = true
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        let card = UIStackView(arrangedSubviews: [
            statusLabel, detailLabel, spacer(8), batteryLabel, batteryBar, binLabel, binBar,
        ])
        card.axis = .vertical
        card.spacing = 6
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16

        modeControl.selectedSegmentIndex = CleaningMode.allCases.firstIndex(of: .standard) ?? 0

        style(primaryButton, title: "Start cleaning", filled: true)
        style(dockButton, title: "Return to dock", filled: false)
        style(emptyBinButton, title: "Empty bin", filled: false)
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        dockButton.addTarget(self, action: #selector(dockTapped), for: .touchUpInside)
        emptyBinButton.addTarget(self, action: #selector(emptyBinTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [connectionRow, card, modeControl, primaryButton, dockButton, emptyBinButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    private func style(_ button: UIButton, title: String, filled: Bool) {
        var config: UIButton.Configuration = filled ? .filled() : .tinted()
        config.title = title
        config.cornerStyle = .large
        config.buttonSize = .large
        button.configuration = config
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }
}
