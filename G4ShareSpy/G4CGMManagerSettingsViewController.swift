//
//  G4CGMManagerSettingsViewController.swift
//  G4ShareSpy
//
//  Copyright © 2018 Mark Wilson. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import ShareClient
import ShareClientUI


class G4CGMManagerSettingsViewController: UITableViewController {

    public let cgmManager: G4CGMManager

    public let glucoseUnit: HKUnit

    public init(cgmManager: G4CGMManager, glucoseUnit: HKUnit) {
        self.cgmManager = cgmManager
        self.glucoseUnit = glucoseUnit

        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = cgmManager.localizedTitle

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
    }

    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case latestReading
        case delete

        static let count = 2
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count
    }

    private enum LatestReadingRow: Int {
        case glucose
        case date
        case trend
        case state

        static let count = 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .latestReading:
            return LatestReadingRow.count
        case .delete:
            return 1
        }
    }

    private lazy var glucoseFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: glucoseUnit)
        return formatter
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .latestReading:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            let glucose = cgmManager.latestReading

            switch LatestReadingRow(rawValue: indexPath.row)! {
            case .glucose:
                cell.setGlucose(glucose?.quantity, unit: glucoseUnit, formatter: glucoseFormatter, isDisplayOnly: glucose?.isDisplayOnly ?? false)
            case .date:
                cell.textLabel?.text = NSLocalizedString("Date", comment: "Title describing glucose date")

                if let date = glucose?.startDate {
                    cell.detailTextLabel?.text = dateFormatter.string(from: date)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .trend:
                cell.textLabel?.text = NSLocalizedString("Trend", comment: "Title describing glucose trend")

                cell.detailTextLabel?.text = glucose?.trendType?.localizedDescription ?? SettingsTableViewCell.NoValueString
            case .state:
                cell.textLabel?.text = NSLocalizedString("Status", comment: "Title describing CGM calibration state")

                if let stateDescription = glucose?.stateDescription, !stateDescription.isEmpty {
                    cell.detailTextLabel?.text = stateDescription
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            }

            return cell
        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = NSLocalizedString("Delete CGM", comment: "Title text for the button to remove a CGM from Loop")
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .latestReading:
            return NSLocalizedString("Latest Reading", comment: "Section title for latest glucose reading")
        case .delete:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .latestReading:
            tableView.deselectRow(at: indexPath, animated: true)
        case .delete:
            let confirmVC = UIAlertController(cgmDeletionHandler: {
                self.cgmManager.cgmManagerDelegate?.cgmManagerWantsDeletion(self.cgmManager)
                self.navigationController?.popViewController(animated: true)
            })

            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
    }
}


private extension SettingsTableViewCell {
    func setGlucose(_ glucose: HKQuantity?, unit: HKUnit, formatter: QuantityFormatter, isDisplayOnly: Bool) {
        if isDisplayOnly {
            textLabel?.text = NSLocalizedString("Glucose (Adjusted)", comment: "Describes a glucose value adjusted to reflect a recent calibration")
        } else {
            textLabel?.text = NSLocalizedString("Glucose", comment: "Title describing glucose value")
        }

        if let quantity = glucose, let formatted = formatter.string(from: quantity, for: unit) {
            detailTextLabel?.text = formatted
        } else {
            detailTextLabel?.text = SettingsTableViewCell.NoValueString
        }
    }
}



private extension UIAlertController {
    convenience init(cgmDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: NSLocalizedString("Are you sure you want to delete this CGM?", comment: "Confirmation message for deleting a CGM"),
            preferredStyle: .actionSheet
        )

        addAction(UIAlertAction(
            title: NSLocalizedString("Delete CGM", comment: "Button title to delete CGM"),
            style: .destructive,
            handler: { (_) in
                handler()
            }
        ))

        let cancel = NSLocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}

