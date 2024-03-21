//
//  PublicKey+Address.swift
// 
//  Copyright © 2019 BitcoinKit developers
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

extension PublicKey {
    @available(*, deprecated, message: "toLegacy() will be removed. Use toBitcoinAddress instead.")
    public func toLegacy() -> Address {
        legacy()
    }

    public func legacy() -> P2pkh {
        P2pkh(pubkey: data, network: network)
    }

    public func taproot() -> P2tr {
        P2tr(internalPubKey: data.xOnly, network: network)
    }

    /// p2sh-p2wph
    public func nestedSegwit() -> P2sh {
        P2sh(redeem: nativeSegwit(), network: network)
    }

    /// p2wpkh
    public func nativeSegwit() -> P2wpkh {
        P2wpkh(pubkey: data, network: network)
    }
}

extension PublicKey {
    public var xOnly: Data {
        data.xOnly
    }
}

extension Data {
    public var xOnly: Data {
        toXOnly(self)
    }
}
