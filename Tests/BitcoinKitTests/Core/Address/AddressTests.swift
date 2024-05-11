//
//  AddressTests.swift
//
//  Copyright © 2018 BitcoinKit developers
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import XCTest
@testable import BitcoinKit

class AddressTests: XCTestCase {
    
    func testInvalidChecksumCashaddr() {
        // invalid address
        do {
            _ = try BitcoinAddress(cashaddr: "bitcoincash:qpjdpjrm5zvp2al5u4uzmp36t9m0ll7gd525rss978💦😆")
            XCTFail("Should throw invalid checksum error.")
        } catch AddressError.invalid {
            // Success
        } catch {
            XCTFail("Should throw invalid checksum error.")
        }
        
        // mismatch scheme and address
        do {
            _ = try BitcoinAddress(cashaddr: "bchtest:qpjdpjrm5zvp2al5u4uzmp36t9m0ll7gd525rss978")
            XCTFail("Should throw invalid checksum error.")
        } catch AddressError.invalid {
            // Success
        } catch {
            XCTFail("Should throw invalid checksum error.")
        }
    }
    
    func testWrongNetworkCashaddr() {
        do {
            _ = try BitcoinAddress(cashaddr: "pref:pr6m7j9njldwwzlg9v7v53unlr4jkmx6ey65nvtks5")
            XCTFail("Should throw invalid scheme error.")
        } catch AddressError.invalidScheme {
            // Success
        } catch {
            XCTFail("Should throw wrong network invalid scheme error.")
        }
    }

    func testDecode() throws {
        XCTAssertEqual(try createAddress(from: "msDtSbsvsGycRVZpcm6d5YA6puhYMrMo1K").script.hex, "76a914806738d85849e50bce67d5d9d4dd7fb025ffd97288ac")
        XCTAssertEqual(try createAddress(from: "tb1qspnn3kzcf8jshnn86hvafhtlkqjllktjugnqvg").script.hex, "0014806738d85849e50bce67d5d9d4dd7fb025ffd972")
        XCTAssertEqual(try createAddress(from: "2NC8Niik7EMYu9MQDo4mJV3moi8GKQkEAx3").script.hex, "a914cf1ec4593539358f73d008abc1e7023257a8cb1f87")
        XCTAssertEqual(try createAddress(from: "tb1pxr2zk4kq3a8e5rl2r59vnxf6gl2lsxrnkmv4ztp95ayakjgsffvs522z2m").script.hex, "512030d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a59")
    }
}
