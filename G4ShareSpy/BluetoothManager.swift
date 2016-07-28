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

    var stayConnected = true

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

    func scanForPeripheral() {
        guard manager.state == .PoweredOn else {
            return
        }

        let receiverService = CBUUID(string: ReceiverServiceUUID.CGMService.rawValue)

        if let peripheral = manager.retrieveConnectedPeripheralsWithServices([receiverService]).first {
            delegate?.bluetoothManagerDidLogEvent(self, event: "scanForPeripheral: Was among connected peripherals, reconnecting")
            connectPeripheral(peripheral)
        } else {
            delegate?.bluetoothManagerDidLogEvent(self, event: "scanForPeripheral: Scanning")
            manager.scanForPeripheralsWithServices([receiverService], options: nil)
        }
    }

    func disconnect() {
        manager.stopScan()

        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
        }
    }

    deinit {
        stayConnected = false
        disconnect()
    }

    private func connectPeripheral(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        peripheral.delegate = self
        manager.connectPeripheral(peripheral, options: nil)
    }

    /**
     Can't hurt to leave this in here, from @loudnate's xDripG5:

     "Persistent connections don't seem to work with the transmitter shutoff: The OS won't re-wake the
     app unless it's scanning.

     The sleep gives the transmitter time to shut down, but keeps the app running."
     */
    private func scanAfterDelay() {
        delegate?.bluetoothManagerDidLogEvent(self, event: "scanAfterDelay")
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            NSThread.sleepForTimeInterval(2)

            self.scanForPeripheral()
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
                scanForPeripheral()
            }
        case .Resetting, .PoweredOff, .Unauthorized, .Unknown, .Unsupported:
            central.stopScan()
        }
    }

    func centralManager(central: CBCentralManager, willRestoreState dict: [String : AnyObject]) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "willRestoreState")
        if peripheral == nil, let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            self.peripheral = peripherals.first
        }
    }

    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverPeripheral")
        connectPeripheral(peripheral)
    }

    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        central.stopScan()

        let knownServiceUUIDs = peripheral.services?.flatMap({ $0.UUID }) ?? []

        let servicesToDiscover = [
            CBUUID(string: ReceiverServiceUUID.CGMService.rawValue)
        ].filter({ !knownServiceUUIDs.contains($0) })

        if servicesToDiscover.count > 0 {
            delegate?.bluetoothManagerDidLogEvent(self, event: "didConnectPeripheral: discovering services")
            peripheral.discoverServices(servicesToDiscover)
        } else {
            delegate?.bluetoothManagerDidLogEvent(self, event: "didConnectPeripheral: already discovered services")
            self.peripheral(peripheral, didDiscoverServices: nil)
        }
    }

    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDisconnectPeripheral (error: \(error))")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        if stayConnected {
            scanAfterDelay()
        }
    }

    func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didFailToConnectPeripheral (error: \(error))")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
        }
        if stayConnected {
            scanAfterDelay()
        }
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
        delegate?.bluetoothManagerDidLogEvent(self, event: "didDiscoverCharacteristics")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
            return
        }
        for characteristic in service.characteristics ?? [] {
            peripheral.setNotifyValue(true, forCharacteristic: characteristic)
        }
        self.delegate?.bluetoothManagerIsReady(self)
    }

    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        delegate?.bluetoothManagerDidLogEvent(self, event: "didUpdateNotificationStateForCharacteristic: \(characteristic.UUID.UUIDString) \(characteristic.isNotifying)")
        if let error = error {
            delegate?.bluetoothManager(self, didError: error)
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
