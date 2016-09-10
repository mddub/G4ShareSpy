//
//  NSDate.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/11/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

// 2009-01-01T00:00:00
let dexcomClockStart: Double = 1230796800

extension Date {
    static func fromDexcomSystemTime(_ seconds: UInt32) -> Date {
        return Date(timeIntervalSince1970: dexcomClockStart + Double(seconds))
    }
}
