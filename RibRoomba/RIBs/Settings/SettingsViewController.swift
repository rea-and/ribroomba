import RIBs
import UIKit

final class SettingsViewController: UITableViewController, SettingsPresentable, SettingsViewControllable, UITextFieldDelegate {

    weak var listener: SettingsPresentableListener?
    private var viewModel = SettingsViewModel(name: "", suction: .balanced, carpetBoost: false, connectionText: "", isEditable: false)

    private let nameField = UITextField()
    private let suctionControl = UISegmentedControl(items: SuctionPower.allCases.map(\.displayName))
    private let carpetSwitch = UISwitch()

    init() {
        super.init(style: .insetGrouped)
        title = "Settings"
        tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape.fill"), tag: 3)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        nameField.delegate = self
        nameField.textAlignment = .right
        nameField.returnKeyType = .done
        suctionControl.addTarget(self, action: #selector(suctionChanged), for: .valueChanged)
        carpetSwitch.addTarget(self, action: #selector(carpetChanged), for: .valueChanged)
        apply()
    }

    func render(_ viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        guard isViewLoaded else { return }
        apply()
        tableView.reloadData()
    }

    private func apply() {
        if !nameField.isFirstResponder { nameField.text = viewModel.name }
        suctionControl.selectedSegmentIndex = SuctionPower.allCases.firstIndex(of: viewModel.suction) ?? 1
        carpetSwitch.isOn = viewModel.carpetBoost
        [nameField, suctionControl, carpetSwitch].forEach { ($0 as UIControl).isEnabled = viewModel.isEditable }
    }

    @objc private func suctionChanged() { listener?.didChangeSuction(SuctionPower.allCases[suctionControl.selectedSegmentIndex]) }
    @objc private func carpetChanged() { listener?.didChangeCarpetBoost(carpetSwitch.isOn) }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        listener?.didChangeName(textField.text ?? "")
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2 else { return }
        if indexPath.row == 0 { listener?.didTapSwitchDevice() } else { listener?.didTapSignOut() }
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 4 : (section == 1 ? 1 : 2) }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Robot", "About", "Account"][section]
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none
        if indexPath.section == 2 {
            cell.selectionStyle = .default
            cell.textLabel?.text = indexPath.row == 0 ? "Switch device" : "Sign out"
            cell.textLabel?.textColor = indexPath.row == 0 ? .systemBlue : .systemRed
            return cell
        }
        guard indexPath.section == 0 else {
            cell.textLabel?.text = "Connection"
            cell.detailTextLabel?.text = viewModel.connectionText + " · Simulated device"
            return cell
        }
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Name"
            nameField.frame = CGRect(x: 0, y: 0, width: 180, height: 44)
            cell.accessoryView = nameField
        case 1:
            cell.textLabel?.text = "Suction"
            cell.contentView.addSubview(suctionControl)
            suctionControl.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                suctionControl.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                suctionControl.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                suctionControl.widthAnchor.constraint(equalToConstant: 210),
            ])
        case 2:
            cell.textLabel?.text = "Carpet boost"
            cell.accessoryView = carpetSwitch
        default:
            cell.textLabel?.text = "Robot model"
            cell.detailTextLabel?.text = "RibRoomba R1 (mock)"
        }
        return cell
    }
}
