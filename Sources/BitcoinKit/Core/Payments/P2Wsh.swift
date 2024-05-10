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
    public private(set) var type: AddressType = .P2WSH(nil)

    public init(redeem: PaymentType, network: Network = .mainnetBTC) {
        let hash = Crypto.sha256(redeem.output)
        self.init(hash: hash, network: network)
        if let address = redeem as? Address {
            self.type = .P2WSH(address.type)
        }
    }

    public init(hash: Data, network: Network = .mainnetBTC) {
        self.network = network
        self.hash = hash
        self.output = try! Script().append(.OP_0).appendData(hash).data

        let words: Data = [0x00] + Bech32.convertTo5bit(data: hash, pad: true)
        self.address = Bech32.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }

    public init(output: Data) throws {
        guard output.count == 34, output[0] == OpCode.OP_0.value, output[1] == 0x20 else {
            throw PaymentError.outputInvalid
        }
        self.init(output: output, network: .mainnetBTC)
    }

    public init(output: Data, network: Network = .mainnetBTC) {
        let hash = output[2...]
        self.init(hash: hash, network: network)
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

    public static func witnessFrom(redeem: PaymentType, input: Data, witness: [Data]) -> [Data] {
//        let input = redeem.inputFromSignature(signature)
        if !input.isEmpty && !redeem.output.isEmpty {
            let chunks = Script(data: input)!.scriptChunks.compactMap({ $0 as? DataChunk }).map(\.pushedData)
            return chunks + [redeem.output]
        }
//        let witness = redeem.witnessFromSignature(signature)
        return witness + [redeem.output]
    }
}
