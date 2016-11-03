//
//  SystemTimeMessage.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/10/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

struct SystemTimeMessage {

    // 0...3 header
    // 4...7 time
    // 8...9 CRC
    static let length = 10

    let time: UInt32

    init?(data: Data) {
        guard data.count == type(of: self).length && data.crcValid() else {
            return nil
        }

        // sanity check that it's not just any 4-byte message, but a plausible date
        let seconds = data[4..<8] as UInt32
        guard abs(Date.fromDexcomSystemTime(seconds).timeIntervalSinceNow) < (10 * 365 * 24 * 60 * 60) else {
            return nil
        }

        time = seconds
    }
    
}
