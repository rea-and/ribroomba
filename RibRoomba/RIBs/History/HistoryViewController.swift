import RIBs
import UIKit

final class HistoryViewController: UITableViewController, HistoryPresentable, HistoryViewControllable {

    weak var listener: HistoryPresentableListener?
    private var viewModel = HistoryViewModel(summary: "", rows: [])
    private let emptyLabel = UILabel()

    init() {
        super.init(style: .insetGrouped)
        title = "History"
        tabBarItem = UITabBarItem(title: "History", image: UIImage(systemName: "clock.fill"), tag: 2)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Clear", style: .plain, target: self, action: #selector(clearTapped))
        emptyLabel.text = "No cleaning history"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        tableView.backgroundView = emptyLabel
        applyViewModel()
    }

    func render(_ viewModel: HistoryViewModel) {
        self.viewModel = viewModel
        guard isViewLoaded else { return }
        applyViewModel()
    }

    private func applyViewModel() {
        emptyLabel.isHidden = !viewModel.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !viewModel.isEmpty
        tableView.reloadData()
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(title: "Clear history?", message: "This removes all cleaning runs.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in self?.listener?.didTapClear() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.rows.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModel.isEmpty ? nil : viewModel.summary
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "row")
        cell.textLabel?.text = row.title
        cell.detailTextLabel?.text = row.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        let badge = UILabel()
        badge.text = row.outcomeText
        badge.font = .preferredFont(forTextStyle: .footnote)
        badge.textColor = row.isCompleted ? .systemGreen : .systemOrange
        badge.sizeToFit()
        cell.accessoryView = badge
        cell.selectionStyle = .none
        return cell
    }
}
