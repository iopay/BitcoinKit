//
//  Taproot.swift
//  
//
//  Created by liugang zhang on 2024/1/29.
//

import Foundation

public struct Taproot {
    public let pubKey: Data
    public let network: Network

    public init(pubKey: Data, network: Network = .mainnetBTC) {
        self.pubKey = pubKey
        self.network = network
    }

    public init(internalKey: Data, network: Network = .mainnetBTC) {
        let pub = tweakKey(pubKey: internalKey, h: nil)
        self.init(pubKey: pub!, network: network)
    }

    public var xOnly: Data {
        pubKey.count == 32 ? pubKey : pubKey.dropFirst()
    }

    public var address: String {
        let words: Data = [0x01] + Bech32.convertTo5bit(data: xOnly, pad: true)
        return Bech32m.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }

    public var output: Data {
        try! Script().append(.OP_1).appendData(pubKey).data
    }
}
