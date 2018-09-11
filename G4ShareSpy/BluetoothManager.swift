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

public enum BluetoothManagerError: Error {
    case failedToFindConnectedReceiver
}

protocol BluetoothManagerDelegate: class {

    /**
     Tells the delegate that the bluetooth manager has finished connecting to and discovering all required services of its peripheral

     - parameter manager: The bluetooth manager
     */
    func bluetoothManagerIsReady(_ manager: BluetoothManager)

    /**
     Tells the delegate that an error occurred while connecting to the peripheral or discovering its services or characteristics

     - parameter error:   An error describing why connection/discovery failed
     */
    func bluetoothManager(_ manager: BluetoothManager, didError error: Error)

    /**
     Tells the delegate that new bytes have arrived on the "Receive" characteristic

     - parameter manager:         The bluetooth manager
     - parameter didReceiveBytes: The received data
     */
    func bluetoothManager(_ manager: BluetoothManager, didReceiveBytes bytes: Data)

    /**
     Diagnostic logging
     */
    func bluetoothManagerDidLogEvent(_ manager: BluetoothManager, event: String)
}

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    weak var delegate: BluetoothManagerDelegate?

    private var manager: CBCentralManager! = nil

    private var peripheral: CBPeripheral?

    // MARK: - GCD Management

    private var managerQueue = DispatchQueue(label: "com.warkmilson.G4ShareSpy.bluetoothManagerQueue", qos: .userInitiated)

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

        guard manager.state == .poweredOn else {
            return
        }

        guard retries > 0 else {
            delegate?.bluetoothManager(self, didError: BluetoothManagerError.failedToFindConnectedReceiver)
            return
        }

        if let peripheral = manager.retrieveConnectedPeripherals(withServices: [CBUUID(string: ReceiverServiceUUID.CGMService.rawValue)]).first {
            delegate?.bluetoothManagerDidLogEvent(self, event: "findConnectedReceiver: Found among connected peripherals, connecting")
            self.peripheral = peripheral
            peripheral.delegate = self
            manager.connect(peripheral, options: nil)
        } else {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).async {
                Thread.sleep(forTimeInterval: 10)
                self.findConnectedReceiver(withRetries: retries - 1)
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "centralManagerDidUpdateState: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            if let peripheral = peripheral {
                central.connect(peripheral, options: nil)
            } else {
                findPeripheral()
            }
        case .resetting, .poweredOff, .unauthorized, .unknown, .unsupported:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "willRestoreState: self.peripheral is \(String(describing: peripheral))")

        if peripheral == nil, let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for restored in peripherals {
                delegate?.bluetoothManagerDidLogEvent(self, event: "willRestoreState: Restoring self.peripheral")
                self.peripheral = restored
                restored.delegate = self
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let service = CBUUID(string: ReceiverServiceUUID.CGMService.rawValue)
        let knownServiceUUIDs = peripheral.services?.compactMap({ $0.uuid }) ?? []

        if knownServiceUUIDs.contains(service) {
            delegate?.bluetoothManagerDidLogEvent(self, event: "didConnectPeripheral: already discovered services")
            self.peripheral(peripheral, didDiscoverServices: nil)
        } else {
            delegate?.bluetoothManagerDidLogEvent(self, event: "didConnectPeripheral: discovering services")
            peripheral.discoverServices([service])
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDisconnectPeripheral (error: \(String(describing: error)))")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        // Connection requests persist until the device reappears.
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didFailToConnectPeripheral (error: \(String(describing: error)))")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        // Connection requests persist until the device reappears.
        central.connect(peripheral, options: nil)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        for service in peripheral.services ?? [] where service.uuid.uuidString == ReceiverServiceUUID.CGMService.rawValue {
            let characteristic = CBUUID(string: CGMServiceCharacteristicUUID.Rx.rawValue)
            let knownCharacteristics = service.characteristics?.compactMap({ $0.uuid }) ?? []

            if knownCharacteristics.contains(characteristic) {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverServices: already discovered characteristics")
                self.peripheral(peripheral, didDiscoverCharacteristicsFor: service, error: nil)
            } else {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverServices: discovering characteristics")
                peripheral.discoverCharacteristics([characteristic], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics: discovered \((service.characteristics ?? []).count) characteristic(s)")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.isNotifying {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics: already notifying: \(characteristic.uuid.uuidString)")
            } else {
                delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics: setting notify value: \(characteristic.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didUpdateNotificationStateForCharacteristic: \(characteristic.uuid.uuidString) \(characteristic.isNotifying)")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        if characteristic.isNotifying {
            self.delegate?.bluetoothManagerIsReady(self)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        if let value = characteristic.value {
            self.delegate?.bluetoothManager(self, didReceiveBytes: value)
        }
    }
}
