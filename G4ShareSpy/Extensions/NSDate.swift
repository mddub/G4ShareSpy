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

extension NSDate {
    static func fromDexcomSystemTime(seconds: UInt32) -> NSDate {
        return NSDate(timeIntervalSince1970: dexcomClockStart + Double(seconds))
    }
}
