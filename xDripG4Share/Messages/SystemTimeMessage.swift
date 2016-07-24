//
//  SystemTimeMessage.swift
//  xDripG4Share
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

    init?(data: NSData) {
        guard data.length == self.dynamicType.length && data.crcValid() else {
            return nil
        }

        // sanity check that it's not just any 4-byte message, but a plausible date
        let seconds = data[4...7] as UInt32
        guard abs(NSDate.fromDexcomSystemTime(seconds).timeIntervalSinceNow) < (7 * 24 * 60 * 60) else {
            return nil
        }

        time = seconds
    }
    
}