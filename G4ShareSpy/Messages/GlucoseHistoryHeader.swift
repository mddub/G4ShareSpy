//
//  GlucoseHistoryPageHeader.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/10/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

struct GlucoseHistoryHeader {

    //  0...3  first index
    //  4...7  record count
    //  8...8  record type (4 == EGV)
    //  9...9  revision (2?)
    // 10...13 page number
    // 14...17 r1 (?)
    // 18...21 r2 (?)
    // 22...25 r3 (?)
    // 26...27 header CRC
    static let length = 28

    let firstIndex: UInt32
    let recordCount: UInt32

    init?(data: Data) {
        guard data.count == type(of: self).length && data.crcValid() else {
            return nil
        }

        guard data[8] as UInt8 == 4 && data[9] as UInt8 == 2 else {
            return nil
        }

        firstIndex = data[0..<4]
        recordCount = data[4..<9]
    }

}
