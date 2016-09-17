//
//  Receiver.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/9/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

public protocol ReceiverDelegate: class {
    func receiver(_ receiver: Receiver, didReadGlucoseHistory glucoseHistory: [GlucoseG4])

    func receiver(_ receiver: Receiver, didError error: Error)

    // Optional diagnostic logging
    func receiver(_ receiver: Receiver, didLogBluetoothEvent event: String)
}

extension ReceiverDelegate {
    func receiver(_ receiver: Receiver, didLogBluetoothEvent event: String) {}
}

public class Receiver: BluetoothManagerDelegate {

    public weak var delegate: ReceiverDelegate?

    private let bluetoothManager = BluetoothManager()

    private var messageInProgress = false
    private var message: NSMutableData?
    private var receivedBytes: UInt16 = 0
    private var expectedBytes: UInt16 = 0

    public var clockOffset: TimeInterval?
    private var glucoseHistoryAwaitingClock: GlucoseHistoryMessage?

    public init() {
        bluetoothManager.delegate = self
    }

    // MARK: - BluetoothManagerDelegate

    func bluetoothManagerIsReady(_ manager: BluetoothManager) {}

    func bluetoothManager(_ manager: BluetoothManager, didError error: Error) {
        self.delegate?.receiver(self, didError: error)
    }

    func bluetoothManager(_ manager: BluetoothManager, didReceiveBytes bytes: Data) {
        if messageInProgress {
            append(bytes)
        } else if bytes.count >= 4, let header = MessageHeader(data: bytes.subdata(in: 0..<4)) {
            messageInProgress = true
            receivedBytes = 0
            expectedBytes = header.totalBytes
            message = NSMutableData(capacity: Int(expectedBytes))
            append(bytes)
        }
    }

    func bluetoothManagerDidLogEvent(_ manager: BluetoothManager, event: String) {
        self.delegate?.receiver(self, didLogBluetoothEvent: event)
    }

    // MARK: - Helpers

    private func append(_ bytes: Data) {
        message!.append(bytes)
        receivedBytes += UInt16(bytes.count)
        if receivedBytes >= expectedBytes {
            messageInProgress = false
            parseMessage(message! as Data, receivedAt: Date())
            message = nil
        }
    }

    private func parseMessage(_ message: Data, receivedAt: Date) {
        if let systemTimeMessage = SystemTimeMessage(data: message) {
            clockOffset = receivedAt.timeIntervalSince1970 - Double(systemTimeMessage.time)
            if let pending = glucoseHistoryAwaitingClock {
                emitGlucose(pending, clockOffset: clockOffset!)
                glucoseHistoryAwaitingClock = nil
            }
        } else if let glucoseHistoryMessage = GlucoseHistoryMessage(data: message) {
            if let offset = clockOffset {
                emitGlucose(glucoseHistoryMessage, clockOffset: offset)
            } else {
                glucoseHistoryAwaitingClock = glucoseHistoryMessage
            }
        }
    }

    private func emitGlucose(_ history: GlucoseHistoryMessage, clockOffset: Double) {
        let glucose = history.records.map({
            return GlucoseG4(
                sequence: $0.sequence,
                glucose: $0.glucose,
                isDisplayOnly: $0.isDisplayOnly,
                trend: $0.trend,
                time: Date(timeIntervalSince1970: Double($0.systemTime) + clockOffset),
                wallTime: $0.wallTime,
                systemTime: $0.systemTime
            )
        })
        self.delegate?.receiver(self, didReadGlucoseHistory: glucose)
    }

}
