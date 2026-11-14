import RIBs
import UIKit

final class ScheduleEditorViewController: UIViewController, ScheduleEditorPresentable, ScheduleEditorViewControllable {

    weak var listener: ScheduleEditorPresentableListener?

    private let timePicker = UIDatePicker()
    private let weekdayControl = UISegmentedControl(items: Calendar.current.veryShortWeekdaySymbols)
    private let modeControl = UISegmentedControl(items: CleaningMode.allCases.map(\.displayName))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))

        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .wheels
        weekdayControl.selectedSegmentIndex = 1
        modeControl.selectedSegmentIndex = 1

        let stack = UIStackView(arrangedSubviews: [label("Day"), weekdayControl, label("Time"), timePicker, label("Mode"), modeControl])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    func render(_ vm: ScheduleEditorViewModel) {
        loadViewIfNeeded()
        title = vm.title
        weekdayControl.selectedSegmentIndex = vm.weekday - 1
        modeControl.selectedSegmentIndex = CleaningMode.allCases.firstIndex(of: vm.mode) ?? 1
        let calendar = Calendar.current
        timePicker.date = calendar.date(bySettingHour: vm.hour, minute: vm.minute, second: 0, of: Date()) ?? Date()
    }

    @objc private func cancelTapped() { listener?.didTapCancel() }

    @objc private func saveTapped() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: timePicker.date)
        listener?.didTapSave(weekday: weekdayControl.selectedSegmentIndex + 1,
                             hour: c.hour ?? 9, minute: c.minute ?? 0,
                             mode: CleaningMode.allCases[modeControl.selectedSegmentIndex])
    }

    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .preferredFont(forTextStyle: .footnote)
        l.textColor = .secondaryLabel
        return l
    }
}
