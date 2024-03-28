//
//  P2Wsh.swift
//
//
//  Created by liugang zhang on 2024/3/28.
//

import Foundation

public struct P2Wsh: PaymentType, Address {
    public let output: Data
    public let hash: Data
    public let address: String
    public let network: Network
    public let type: AddressType = .P2WSH

    public init(hash: Data, network: Network = .mainnetBTC) {
        self.network = network
        self.hash = hash
        self.output = try! Script().append(.OP_0).appendData(hash).data

        let words: Data = [0x00] + Bech32.convertTo5bit(data: hash, pad: true)
        self.address = Bech32.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }

    public init(address: String) throws {
        guard let (prefix, data) = Bech32.decode(address, separator: "1"), data.count == 32 else {
            throw PaymentError.addressInvalid
        }
        switch prefix {
        case Network.mainnetBTC.bech32Prefix:
            self.network = .mainnetBTC
        case Network.testnetBTC.bech32Prefix:
            self.network = .testnetBTC
        default:
            throw PaymentError.addressInvalid
        }

        self.address = address
        self.hash = data
        self.output = try! Script().append(.OP_0).appendData(data).data
    }
}
