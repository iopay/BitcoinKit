//
//  P2MS.swift
//
//
//  Created by liugang zhang on 2024/4/16.
//

import Foundation

public struct P2MS: WitnessPaymentType {
    static let OP_INT_BASE = OpCode.OP_RESERVED.value

    public let output: Data
    public let pubkeys: [Data]
    public let m: UInt8
    public let n: UInt8

    public init(output: Data) throws {
        guard let chunks = Script(data: output)?.scriptChunks,
              chunks.count > 4,
              chunks.last?.opcodeValue == OpCode.OP_CHECKMULTISIG.value else {
            throw PaymentError.outputInvalid
        }
        let m = chunks[0].opcodeValue - P2MS.OP_INT_BASE
        let n = chunks[chunks.count - 2].opcodeValue - P2MS.OP_INT_BASE
        let pubkeys = chunks[1..<chunks.count - 2].compactMap({ $0 as? DataChunk }).map(\.pushedData)
        guard m > 0, n <= 16, m <= n, n == pubkeys.count else {
            throw PaymentError.outputInvalid
        }
        self.output = output
        self.m = m
        self.n = n
        self.pubkeys = pubkeys
    }

    public init(pubkeys: [Data], m: UInt8) throws {
        self.pubkeys = pubkeys
        self.m = m
        self.n = UInt8(pubkeys.count)
        self.output = try Script()
            .append(OpCodeFactory.get(with: m + P2MS.OP_INT_BASE))
            .appendData(pubkeys)
            .data
    }

    public func witnessFromSignature(_ sig: [PartialSig]) -> [Data] {
        []
    }

    public func inputFromSignature(_ sig: [PartialSig]) -> Data {
        let sigs = getSortedSigs(partialSig: sig)
        return try! Script().append(.OP_0).appendData(sigs).data
    }

    func getSortedSigs(partialSig: [PartialSig]) -> [Data] {
        pubkeys.compactMap { pub in
            partialSig.filter { $0.pubkey == pub }.first?.signature
        }
    }
}
