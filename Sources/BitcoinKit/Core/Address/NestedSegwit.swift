//
//  NestedSegwit.swift
//
//
//  Created by liugang zhang on 2024/2/19.
//

import Foundation

public struct NestedSegwit {
    public let pubKey: Data
    public let network: Network

    public init(pubKey: Data, network: Network) {
        self.pubKey = pubKey
        self.network = network
    }

    public var address: String {
        var hash = Crypto.sha256ripemd160(pubKey)
        hash = Crypto.sha256ripemd160([0x00, 0x14] + hash)
        let c: Data = [network.scripthash] + hash
        hash = Crypto.sha256sha256(c)
        hash = c + hash[0..<4]
        return Base58.encode(hash)
    }
}
