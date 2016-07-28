//
//  GlucoseHistoryMessage.swift
//  G4ShareSpy
//
//  Created by Mark Wilson on 7/10/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import Foundation

struct GlucoseHistoryMessage {

    let records: [GlucoseHistoryRecord]

    init?(data: NSData) {
        guard data.length > (MessageHeader.length + GlucoseHistoryHeader.length) && data.crcValid() else {
            return nil
        }

        let pageHeaderData = data.subdataWithRange(NSMakeRange(MessageHeader.length, GlucoseHistoryHeader.length))
        guard let pageHeader = GlucoseHistoryHeader(data: pageHeaderData) else {
            return nil
        }

        records = (0..<pageHeader.recordCount).map({
            let range = NSMakeRange(
                MessageHeader.length + GlucoseHistoryHeader.length + GlucoseHistoryRecord.length * Int($0),
                GlucoseHistoryRecord.length
            )
            return GlucoseHistoryRecord(data: data.subdataWithRange(range), index: pageHeader.firstIndex + $0)!
        })
    }
    
}
