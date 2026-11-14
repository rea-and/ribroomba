import RIBs
import UIKit

final class AddDeviceViewController: UITableViewController, AddDevicePresentable, AddDeviceViewControllable {

    weak var listener: AddDevicePresentableListener?
    private var viewModel = AddDeviceViewModel(isScanning: false, isPairing: false, rows: [], errorMessage: nil)
    private let spinner = UIActivityIndicatorView(style: .medium)

    init() {
        super.init(style: .insetGrouped)
        title = "Add robot"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        apply()
    }

    func render(_ viewModel: AddDeviceViewModel) {
        self.viewModel = viewModel
        guard isViewLoaded else { return }
        apply()
    }

    private func apply() {
        viewModel.isScanning || viewModel.isPairing ? spinner.startAnimating() : spinner.stopAnimating()
        let rescan = UIBarButtonItem(title: "Rescan", style: .plain, target: self, action: #selector(rescanTapped))
        navigationItem.rightBarButtonItem = (viewModel.isScanning || viewModel.isPairing) ? UIBarButtonItem(customView: spinner) : rescan
        tableView.reloadData()
    }

    @objc private func cancelTapped() { listener?.didTapCancel() }
    @objc private func rescanTapped() { listener?.didTapRescan() }

    // MARK: - Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { viewModel.rows.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { viewModel.statusText }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { viewModel.errorMessage }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = .systemRed
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = viewModel.rows[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = row.name
        cell.detailTextLabel?.text = row.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        let symbol = ["wifi.exclamationmark", "wifi", "wifi", "wifi"][min(max(row.signalBars, 1), 4) - 1]
        cell.imageView?.image = UIImage(systemName: symbol)
        if row.isPairing {
            let s = UIActivityIndicatorView(style: .medium)
            s.startAnimating()
            cell.accessoryView = s
        }
        cell.isUserInteractionEnabled = !viewModel.isPairing
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        listener?.didSelect(id: viewModel.rows[indexPath.row].id)
    }
}
