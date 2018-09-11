//
//  G4CGMManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import ShareClient
import HealthKit


public class G4CGMManager: CGMManager, ReceiverDelegate {
    public static let managerIdentifier: String = "DexG4ShareReceiver"

    init() {
        receiver.delegate = self
    }

    required convenience public init?(rawState: CGMManager.RawStateValue) {
        self.init()
    }

    public var rawState: CGMManager.RawStateValue {
        return [:]
    }

    weak public var cgmManagerDelegate: CGMManagerDelegate? {
        didSet {
            shareManager.cgmManagerDelegate = cgmManagerDelegate
        }
    }

    public static let localizedTitle = NSLocalizedString("Dexcom G4", comment: "CGM display title")

    public let shouldSyncToRemoteService = false

    let shareManager = ShareClientManager()

    private let receiver = Receiver()

    public var providesBLEHeartbeat: Bool {
        return dataIsFresh
    }

    public var sensorState: SensorDisplayable? {
        return latestReading ?? shareManager.sensorState
    }

    public var managedDataInterval: TimeInterval? {
        return .hours(3)
    }

    private(set) var latestReading: GlucoseG4?

    private var dataIsFresh: Bool {
        guard let latestGlucose = latestReading,
            latestGlucose.startDate > Date(timeIntervalSinceNow: .minutes(-4.5)) else {
                return false
        }

        return true
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) {
        // If our last glucose was less than 4.5 minutes ago, don't fetch.
        guard !dataIsFresh else {
            completion(.noData)
            return
        }

        shareManager.fetchNewDataIfNeeded(completion)
    }

    public var device: HKDevice? {
        // "Dexcom G4 Platinum Transmitter (Retail) US" - see https://accessgudid.nlm.nih.gov/devices/search?query=dexcom+g4
        return HKDevice(
            name: "G4ShareSpy",
            manufacturer: "Dexcom",
            model: "G4 Share",
            hardwareVersion: nil,
            firmwareVersion: nil,
            softwareVersion: String(G4ShareSpyVersionNumber),
            localIdentifier: nil,
            udiDeviceIdentifier: "40386270000048"
        )
    }

    public var debugDescription: String {
        return [
            "## G4CGMManager",
            "shareManager: \(String(reflecting: shareManager))",
            "latestReading: \(String(describing: latestReading))",
            "receiver: \(receiver)",
            "providesBLEHeartbeat: \(providesBLEHeartbeat)",
            ""
        ].joined(separator: "\n")
    }

    // MARK: - ReceiverDelegate

    public func receiver(_ receiver: Receiver, didReadGlucoseHistory glucoseHistory: [GlucoseG4]) {
        guard let latest = glucoseHistory.sorted(by: { $0.sequence < $1.sequence }).last, latest != latestReading else {
            return
        }
        latestReading = latest

        // In the event that some of the glucose history was already backfilled from Share, don't overwrite it.
        let includeAfter = cgmManagerDelegate?.startDateToFilterNewData(for: self)?.addingTimeInterval(TimeInterval(minutes: 1))

        let validGlucose = glucoseHistory.filter({
            $0.isStateValid
        }).filterDateRange(includeAfter, nil).map({
            NewGlucoseSample(date: $0.startDate, quantity: $0.quantity, isDisplayOnly: $0.isDisplayOnly, syncIdentifier: String(describing: $0.sequence), device: self.device)
        })

        self.cgmManagerDelegate?.cgmManager(self, didUpdateWith: .newData(validGlucose))
    }

    public func receiver(_ receiver: Receiver, didError error: Error) {
        cgmManagerDelegate?.cgmManager(self, didUpdateWith: .error(error))
    }

    public func receiver(_ receiver: Receiver, didLogBluetoothEvent event: String) {
        // Uncomment to debug communication
        // NSLog("\(#function): \(event)")
    }
}
