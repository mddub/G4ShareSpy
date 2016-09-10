//
//  MessageHeader.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/10/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

struct MessageHeader {

    // 0...0 indicates start of header (1)
    // 1...2 total bytes
    // 3...3 ACK (1)
    static let length = 4

    let totalBytes: UInt16

    init?(data: Data) {
        guard data.count == type(of: self).length else {
            return nil
        }

        guard data[0] as UInt8 == 1 && data[3] as UInt8 == 1 else {
            return nil
        }

        totalBytes = data[1..<3]
    }

}
