import RIBs
import UIKit

final class ScheduleViewController: UITableViewController, SchedulePresentable, ScheduleViewControllable {

    weak var listener: SchedulePresentableListener?
    private var viewModel = ScheduleViewModel(rows: [])
    private let emptyLabel = UILabel()

    init() {
        super.init(style: .insetGrouped)
        title = "Schedule"
        tabBarItem = UITabBarItem(title: "Schedule", image: UIImage(systemName: "calendar"), tag: 1)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped))
        emptyLabel.text = "No cleaning scheduled.\nTap + to add one."
        emptyLabel.numberOfLines = 0
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        tableView.backgroundView = emptyLabel
        emptyLabel.isHidden = !viewModel.isEmpty
    }

    func render(_ viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        guard isViewLoaded else { return }
        emptyLabel.isHidden = !viewModel.isEmpty
        tableView.reloadData()
    }

    func presentModal(_ viewController: ViewControllable) {
        let nav = UINavigationController(rootViewController: viewController.uiviewController)
        nav.isModalInPresentation = true  // only Save/Cancel may close it, so the RIB is always detached.
        present(nav, animated: true)
    }

    func dismissModal() {
        presentedViewController?.dismiss(animated: true)
    }

    @objc private func addTapped() { listener?.didTapAdd() }

    @objc private func switchChanged(_ sender: UISwitch) {
        guard sender.tag < viewModel.rows.count else { return }
        listener?.didToggle(id: viewModel.rows[sender.tag].id, isEnabled: sender.isOn)
    }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        let toggle = UISwitch()
        toggle.isOn = row.isEnabled
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
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
