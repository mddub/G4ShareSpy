//
//  GlucoseG4.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/10/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

public struct GlucoseG4 {

    public let sequence: UInt32
    public let glucose: UInt16
    public let isDisplayOnly: Bool
    public let trend: UInt8
    public let time: Date
    public let wallTime: Date
    public let systemTime: UInt32
    
}

extension GlucoseG4: Equatable {
}

public func ==(lhs: GlucoseG4, rhs: GlucoseG4) -> Bool {
    return lhs.sequence == rhs.sequence
}
