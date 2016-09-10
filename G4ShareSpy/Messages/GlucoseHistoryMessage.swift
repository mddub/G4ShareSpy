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

    init?(data: Data) {
        guard data.count > (MessageHeader.length + GlucoseHistoryHeader.length) && data.crcValid() else {
            return nil
        }

        let pageHeaderData = data.subdata(in: MessageHeader.length..<(MessageHeader.length + GlucoseHistoryHeader.length))
        guard let pageHeader = GlucoseHistoryHeader(data: pageHeaderData) else {
            return nil
        }

        records = (0..<pageHeader.recordCount).map({
            let start = MessageHeader.length + GlucoseHistoryHeader.length + GlucoseHistoryRecord.length * Int($0)

            let range = Range<Int>(uncheckedBounds: (lower: start, upper: start + GlucoseHistoryRecord.length))
            return GlucoseHistoryRecord(data: data.subdata(in: range), index: pageHeader.firstIndex + $0)!
        })
    }
    
}
