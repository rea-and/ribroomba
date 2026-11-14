import RIBs
import UIKit

final class DevicesViewController: UITableViewController, DevicesPresentable, DevicesViewControllable {

    weak var listener: DevicesPresentableListener?
    private var viewModel = DevicesViewModel(greeting: "", rows: [])
    private let emptyLabel = UILabel()

    init() {
        super.init(style: .insetGrouped)
        title = "My robots"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Sign out", style: .plain, target: self, action: #selector(signOutTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        emptyLabel.text = "No robots yet.\nTap + to search for nearby robots."
        emptyLabel.numberOfLines = 0
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        tableView.backgroundView = emptyLabel
        apply()
    }

    func render(_ viewModel: DevicesViewModel) {
        self.viewModel = viewModel
        guard isViewLoaded else { return }
        apply()
    }

    func showError(_ message: String) {
        let alert = UIAlertController(title: "Robots", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func presentModal(_ viewController: ViewControllable) {
        let nav = UINavigationController(rootViewController: viewController.uiviewController)
        nav.isModalInPresentation = true
        present(nav, animated: true)
    }

    func dismissModal() {
        presentedViewController?.dismiss(animated: true)
    }

    private func apply() {
        emptyLabel.isHidden = !viewModel.isEmpty
        tableView.reloadData()
    }

    @objc private func addTapped() { listener?.didTapAdd() }
    @objc private func signOutTapped() { listener?.didTapSignOut() }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.rows.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { viewModel.greeting }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = row.name
        cell.detailTextLabel?.text = row.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.imageView?.image = UIImage(systemName: "fanblades.fill")
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        listener?.didSelect(id: viewModel.rows[indexPath.row].id)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        listener?.didDelete(id: viewModel.rows[indexPath.row].id)
    }
}
