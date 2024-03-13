//
//  UnspentTransaction.swift
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

import Foundation

public struct UnspentTransaction {
    public let output: TransactionOutput
    public let outpoint: TransactionOutPoint

    public var tapInternalKey: Data?
    public var redeemScript: Data?
    public var witnessScript: Data?

    public init(output: TransactionOutput, outpoint: TransactionOutPoint, redeemScript: Data? = nil, witnessScript: Data? = nil, tapInternalKey: Data? = nil) {
        self.output = output
        self.outpoint = outpoint
        self.redeemScript = redeemScript
        self.witnessScript = witnessScript
        self.tapInternalKey = tapInternalKey
    }
}

extension UnspentTransaction {
    var isP2SH: Bool {
        redeemScript != nil
    }

    var isP2WSH: Bool {
        witnessScript != nil
    }

    var isSegwit: Bool {
        isP2WSH || isP2WPKH(script)
    }

    var script: Data {
        if let redeemScript = redeemScript {
            return redeemScript
        } else if let witnessScript = witnessScript {
            return witnessScript
        } else {
            return output.lockingScript
        }
    }
}
