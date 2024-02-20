//
//  NativeSegwit.swift
//
//
//  Created by liugang zhang on 2024/2/19.
//

import Foundation

public struct NativeSegwit {
    public let pubKey: Data
    public let network: Network

    public init(pubKey: Data, network: Network) {
        self.pubKey = pubKey
        self.network = network
    }

    public var address: String {
        let hash = Crypto.sha256ripemd160(pubKey)
        let words: Data = [0x00] + Bech32.convertTo5bit(data: hash, pad: true)
        return Bech32.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }
}
