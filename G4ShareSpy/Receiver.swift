//
//  Receiver.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/9/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

public protocol ReceiverDelegate: class {
    func receiver(receiver: Receiver, didReadGlucoseHistory glucoseHistory: [GlucoseG4])

    func receiver(receiver: Receiver, didError error: ErrorType)

    // Optional diagnostic logging
    func receiver(receiver: Receiver, didLogBluetoothEvent event: String)
}

extension ReceiverDelegate {
    func receiver(receiver: Receiver, didLogBluetoothEvent event: String) {}
}

public class Receiver: BluetoothManagerDelegate {

    public weak var delegate: ReceiverDelegate?

    private let bluetoothManager = BluetoothManager()

    private var messageInProgress = false
    private var message: NSMutableData?
    private var receivedBytes: UInt16 = 0
    private var expectedBytes: UInt16 = 0

    public var clockOffset: NSTimeInterval?
    private var glucoseHistoryAwaitingClock: GlucoseHistoryMessage?

    public init() {
        bluetoothManager.delegate = self
    }

    // MARK: - BluetoothManagerDelegate

    func bluetoothManagerIsReady(manager: BluetoothManager) {}

    func bluetoothManager(manager: BluetoothManager, didError error: ErrorType) {
        self.delegate?.receiver(self, didError: error)
    }

    func bluetoothManager(manager: BluetoothManager, didReceiveBytes bytes: NSData) {
        if messageInProgress {
            append(bytes)
        } else if bytes.length >= 4, let header = MessageHeader(data: bytes[0...3]) {
            messageInProgress = true
            receivedBytes = 0
            expectedBytes = header.totalBytes
            message = NSMutableData(capacity: Int(expectedBytes))
            append(bytes)
        }
    }

    func bluetoothManagerDidLogEvent(manager: BluetoothManager, event: String) {
        self.delegate?.receiver(self, didLogBluetoothEvent: event)
    }

    // MARK: - Helpers

    private func append(bytes: NSData) {
        message!.appendData(bytes)
        receivedBytes += UInt16(bytes.length)
        if receivedBytes >= expectedBytes {
            messageInProgress = false
            parseMessage(message!, receivedAt: NSDate())
            message = nil
        }
    }

    private func parseMessage(message: NSData, receivedAt: NSDate) {
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

    private func emitGlucose(history: GlucoseHistoryMessage, clockOffset: Double) {
        let glucose = history.records.map({
            return GlucoseG4(
                sequence: $0.sequence,
                glucose: $0.glucose,
                isDisplayOnly: $0.isDisplayOnly,
                trend: $0.trend,
                time: NSDate(timeIntervalSince1970: Double($0.systemTime) + clockOffset),
                wallTime: $0.wallTime,
                systemTime: $0.systemTime
            )
        })
        self.delegate?.receiver(self, didReadGlucoseHistory: glucose)
    }

}
