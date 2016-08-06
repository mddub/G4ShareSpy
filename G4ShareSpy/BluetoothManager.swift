//
//  BluetoothManager.swift
//  G4ShareSpy
//
//  Adapted heavily from xDripG5 by @loudnate:
//  https://github.com/loudnate/xDripG5/blob/c6b506/xDripG5/BluetoothManager.swift
//
//  Created by Mark Wilson on 7/9/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import CoreBluetooth
import Foundation

public enum BluetoothManagerError: ErrorType {
    case FailedToFindConnectedReceiver
}

protocol BluetoothManagerDelegate: class {

    /**
     Tells the delegate that the bluetooth manager has finished connecting to and discovering all required services of its peripheral

     - parameter manager: The bluetooth manager
     */
    func bluetoothManagerIsReady(manager: BluetoothManager)

    /**
     Tells the delegate that an error occurred while connecting to the peripheral or discovering its services or characteristics

     - parameter error:   An error describing why connection/discovery failed
     */
    func bluetoothManager(manager: BluetoothManager, didError error: ErrorType)

    /**
     Tells the delegate that new bytes have arrived on the "Receive" characteristic

     - parameter manager:         The bluetooth manager
     - parameter didReceiveBytes: The received data
     */
    func bluetoothManager(manager: BluetoothManager, didReceiveBytes bytes: NSData)

    /**
     Diagnostic logging
     */
    func bluetoothManagerDidLogEvent(manager: BluetoothManager, event: String)
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    weak var delegate: BluetoothManagerDelegate?

    private var manager: CBCentralManager! = nil

    private var peripheral: CBPeripheral?

    // MARK: - GCD Management

    private var managerQueue = dispatch_queue_create("com.warkmilson.G4ShareSpy.bluetoothManagerQueue", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0))

    override init() {
        super.init()

        manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: "com.warkmilson.G4ShareSpy"])
    }

    // MARK: - Actions

    func findPeripheral() {
        findConnectedReceiver(withRetries: 12)
    }

    func disconnect() {
        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
        }
    }

    deinit {
        disconnect()
    }

    /**
     We expect the Dexcom Share app to discover and connect to the receiver, so we should never need
     to scan. Instead, we wait for the receiver to appear in the list of connected peripherals.
     */
    private func findConnectedReceiver(withRetries retries: Int) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "findConnectedReceiver: retries = \(retries)")

        guard manager.state == .PoweredOn else {
            return
        }

        guard retries > 0 else {
            delegate?.bluetoothManager(self, didError: BluetoothManagerError.FailedToFindConnectedReceiver)
            return
        }

        if let peripheral = manager.retrieveConnectedPeripheralsWithServices([CBUUID(string: ReceiverServiceUUID.CGMService.rawValue)]).first {
            delegate?.bluetoothManagerDidLogEvent(self, event: "findConnectedReceiver: Found among connected peripherals, connecting")
            self.peripheral = peripheral
            peripheral.delegate = self
            manager.connectPeripheral(peripheral, options: nil)
        } else {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                NSThread.sleepForTimeInterval(10)
                self.findConnectedReceiver(withRetries: retries - 1)
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(central: CBCentralManager) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "centralManagerDidUpdateState: \(central.state.rawValue)")
        switch central.state {
        case .PoweredOn:
            if let peripheral = peripheral {
                central.connectPeripheral(peripheral, options: nil)
            } else {
                findPeripheral()
            }
        case .Resetting, .PoweredOff, .Unauthorized, .Unknown, .Unsupported:
            break
        }
    }

    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "willRestoreState")
        if peripheral == nil, let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            self.peripheral = peripherals.first
        }
    }

    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        let service = CBUUID(string: ReceiverServiceUUID.CGMService.rawValue)
        let knownServiceUUIDs = peripheral.services?.flatMap({ $0.UUID }) ?? []

        if knownServiceUUIDs.contains(service) {
            delegate?.bluetoothManagerDidLogEvent(self, event: "didConnectPeripheral: already discovered services")
            self.peripheral(peripheral, didDiscoverServices: nil)
        } else {
            delegate?.bluetoothManagerDidLogEvent(self, event: "didConnectPeripheral: discovering services")
            peripheral.discoverServices([service])
        }
    }

    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDisconnectPeripheral (error: \(error))")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        // Connection requests persist until the device reappears.
        central.connectPeripheral(peripheral, options: nil)
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didFailToConnectPeripheral (error: \(error))")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        // Connection requests persist until the device reappears.
        central.connectPeripheral(peripheral, options: nil)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        for service in peripheral.services ?? [] where service.UUID.UUIDString == ReceiverServiceUUID.CGMService.rawValue {
            let characteristic = CBUUID(string: CGMServiceCharacteristicUUID.Rx.rawValue)
            let knownCharacteristics = service.characteristics?.flatMap({ $0.UUID }) ?? []

            if knownCharacteristics.contains(characteristic) {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverServices: already discovered characteristics")
                self.peripheral(peripheral, didDiscoverCharacteristicsForService: service, error: nil)
            } else {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverServices: discovering characteristics")
                peripheral.discoverCharacteristics([characteristic], forService: service)
            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics: discovered \((service.characteristics ?? []).count) characteristic(s)")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.isNotifying {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics: already notifying: \(characteristic.UUID.UUIDString)")
            } else {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics: setting notify value: \(characteristic.UUID.UUIDString)")
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didUpdateNotificationStateForCharacteristic: \(characteristic.UUID.UUIDString) \(characteristic.isNotifying)")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        if characteristic.isNotifying {
            self.delegate?.bluetoothManagerIsReady(self)
        }
    }

    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        if let value = characteristic.value {
            self.delegate?.bluetoothManager(self, didReceiveBytes: value)
        }
    }
}
