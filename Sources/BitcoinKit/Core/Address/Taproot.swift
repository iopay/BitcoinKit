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

    init(pubKey: Data, network: Network) {
        self.pubKey = pubKey
        self.network = network
    }

    var xOnly: Data {
        pubKey.count == 32 ? pubKey : pubKey.dropFirst()
    }

    var address: String {
        let words: Data = [0x01] + Bech32.convertTo5bit(data: xOnly, pad: true)
        let prefix = "tb"
        return Bech32m.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }
}
