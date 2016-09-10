//
//  GlucoseHistoryMessageTests.swift
//  G4ShareSpyTests
//
//  Created by Mark on 7/21/16.
//  Copyright © 2016 Mark Wilson. All rights reserved.
//

import XCTest
@testable import G4ShareSpy

let historyBytesHex = [
    "0116020130d200001a0000000402880500000000",
    "00000000000000000000fe4d02cf360ed77b360e",
    "590015596f2ed0360e037d360e5c001455025ad1",
    "360e2f7e360e6b00148d3586d2360e5b7f360e6c",
    "0013b91ab2d3360e8780360e670014501cded436",
    "0eb381360e68001416ec0ad6360edf82360e6a00",
    "1468ba37d7360e0b84360e680014c36262d8360e",
    "3785360e5b0014277e8ed9360e6386360e4e0015",
    "add8bada360e8f87360e43001678bae6db360ebb",
    "88360e3b0016fd1b12dd360ee789360e36001553",
    "843ede360e138b360e370014202e6adf360e3f8c",
    "360e34001446ac96e0360e6b8d360e3500145ccf",
    "c2e1360e978e360e350014a553eee2360ec38f36",
    "0e39001449a01ae4360eee90360e3e0014626e46",
    "e5360e1a92360e400014114572e6360e4693360e",
    "480014230e9ee7360e7294360e4b0014f0fccae8",
    "360e9e95360e4b0014c6e5f6e9360eca96360e59",
    "009437df22eb360ef697360e580094ceb122eb36",
    "0ef797360e588014bf83ffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffffffffffffffffffff",
    "ffffffffffffffffffffffff6d52",
].joined(separator: "")

class GlucoseHistoryMessageTests: XCTestCase {

    func testHistory() {
        let data = Data(hexadecimalString: historyBytesHex)!

        let history = GlucoseHistoryMessage(data: data)
        XCTAssertNotNil(history)
        
        if let history = history {
            XCTAssertEqual(history.records.count, 26)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

            XCTAssertEqual(history.records[0].sequence, 53808)
            XCTAssertEqual(history.records[0].glucose, 89)
            XCTAssertEqual(history.records[0].trend, 5)
            XCTAssertEqual(history.records[0].isDisplayOnly, false)
            XCTAssertEqual(history.records[0].systemTime, 238472962)
            XCTAssertEqual(history.records[0].wallTime, dateFormatter.date(from: "2016-07-23T4:34:31Z"))

            XCTAssertEqual(history.records[25].sequence, 53833)
            XCTAssertEqual(history.records[25].glucose, 88)
            XCTAssertEqual(history.records[25].trend, 4)
            XCTAssertEqual(history.records[25].isDisplayOnly, true)
            XCTAssertEqual(history.records[25].systemTime, 238480162)
            XCTAssertEqual(history.records[25].wallTime, dateFormatter.date(from: "2016-07-23T06:34:31Z"))
        }
    }

    func testBadCRC() {
        let data = Data(
            hexadecimalString: historyBytesHex.substring(to: historyBytesHex.characters.index(historyBytesHex.endIndex, offsetBy: -1)) + "3"
        )!

        XCTAssertNil(GlucoseHistoryMessage(data: data))
    }
    
}
