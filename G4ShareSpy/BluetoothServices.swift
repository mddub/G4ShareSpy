//
//  BluetoothServices.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/9/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

/*
Dexcom G4 BLE attributes, via:
https://github.com/StephenBlackWasAlreadyTaken/xDrip/blob/af20e/app/src/main/java/com/eveningoutpost/dexdrip/UtilityModels/DexShareAttributes.java
*/

enum ReceiverServiceUUID: String {
    case CGMService = "F0ACA0B1-EBFA-F96F-28DA-076C35A521DB"
    case DeviceInfo = "00001804-0000-1000-8000-00805f9b34fb"
}


enum CGMServiceCharacteristicUUID: String {
    // Read/Write
    case Tx = "F0ACB20A-EBFA-F96F-28DA-076C35A521DB"
    // Read/Indicate
    case Rx = "F0ACB20B-EBFA-F96F-28DA-076C35A521DB"
    // Read/Write
    case Auth = "F0ACACAC-EBFA-F96F-28DA-076C35A521DB"
    // Read/Notify
    case Heartbeat = "F0AC2B18-EBFA-F96F-28DA-076C35A521DB"
}


enum DeviceInfoCharacteristicUUID: String {
    case ModelNumberString = "2A24"
    case FirmwareRevisionString = "2A26"
    case HardwareRevisionString = "2A27"
    case ManufacturerNameString = "2A29"
}
