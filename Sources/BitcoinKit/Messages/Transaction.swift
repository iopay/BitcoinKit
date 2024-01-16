//
//  Transaction.swift
//
//  Copyright © 2018 Kishikawa Katsumi
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

/// tx describes a bitcoin transaction, in reply to getdata
public struct Transaction {
    private let ADVANCED_TRANSACTION_MARKER: UInt8 = 0x00
    private let ADVANCED_TRANSACTION_FLAG: UInt8 = 0x01
    /// Transaction data format version (note, this is signed)
    public let version: UInt32
    /// If present, always 0001, and indicates the presence of witness data
    // public let flag: UInt16 // If present, always 0001, and indicates the presence of witness data
    /// Number of Transaction inputs (never zero)
    public var txInCount: VarInt {
        return VarInt(inputs.count)
    }
    /// A list of 1 or more transaction inputs or sources for coins
    public let inputs: [TransactionInput]
    /// Number of Transaction outputs
    public var txOutCount: VarInt {
        return VarInt(outputs.count)
    }
    /// A list of 1 or more transaction outputs or destinations for coins
    public let outputs: [TransactionOutput]
    /// A list of witnesses, one for each input; omitted if flag is omitted above
    // public let witnesses: [TransactionWitness] // A list of witnesses, one for each input; omitted if flag is omitted above
    /// The block number or timestamp at which this transaction is unlocked:
    public let lockTime: UInt32

    public var txHash: Data {
        return Crypto.sha256sha256(serialized())
    }

    public var txID: String {
        return Data(txHash.reversed()).hex
    }

    public var hasWitnesses: Bool {
        for ins in inputs {
            if ins.witness.count != 0 {
                return true
            }
        }
        return false
    }

    public init(version: UInt32, inputs: [TransactionInput], outputs: [TransactionOutput], lockTime: UInt32) {
        self.version = version
        self.inputs = inputs
        self.outputs = outputs
        self.lockTime = lockTime
    }

    public func serialized() -> Data {
        var data = Data()
        data += version
        if hasWitnesses {
            data += ADVANCED_TRANSACTION_MARKER
            data += ADVANCED_TRANSACTION_FLAG
        }
        data += txInCount.serialized()
        data += inputs.flatMap { $0.serialized() }
        data += txOutCount.serialized()
        data += outputs.flatMap { $0.serialized() }
        if hasWitnesses {
            inputs.forEach { ins in
                data += VarInt(ins.witness.count).data
                ins.witness.forEach { wit in
                    data += VarInt(wit.count).data
                    data += wit
                }
            }
        }
        data += lockTime
        return data
    }

    public func isCoinbase() -> Bool {
        return inputs.count == 1 && inputs[0].isCoinbase()
    }

    public static func deserialize(_ data: Data) -> Transaction {
        let byteStream = ByteStream(data)
        return deserialize(byteStream)
    }

    static func deserialize(_ byteStream: ByteStream) -> Transaction {
        let version = byteStream.read(UInt32.self)
        let txInCount = byteStream.read(VarInt.self)
        var inputs = [TransactionInput]()
        for _ in 0..<Int(txInCount.underlyingValue) {
            inputs.append(TransactionInput.deserialize(byteStream))
        }
        let txOutCount = byteStream.read(VarInt.self)
        var outputs = [TransactionOutput]()
        for _ in 0..<Int(txOutCount.underlyingValue) {
            outputs.append(TransactionOutput.deserialize(byteStream))
        }
        let lockTime = byteStream.read(UInt32.self)
        return Transaction(version: version, inputs: inputs, outputs: outputs, lockTime: lockTime)
    }
}

extension Transaction {
    func hashForWitnessV0(index: Int, prevOutScript: Data, value: UInt64, hashType: SighashType) -> Data {
        var hashOutputs = Data()
        var hashPrevouts = Data()
        var hashSequence = Data()

        if !hashType.isAnyoneCanPay {
            var data = Data()
            for txIn in inputs {
                data += txIn.previousOutput.serialized()
            }

            hashPrevouts = Crypto.sha256sha256(data)
        }

        if !hashType.isAnyoneCanPay && !hashType.isSingle && !hashType.isNone {
            var data = Data()
            for txIn in inputs {
                data += txIn.sequence
            }
            hashSequence = Crypto.sha256sha256(data)
        }

        if !hashType.isSingle && !hashType.isNone {
            var data = Data()
            for txOut in outputs {
                data += txOut.serialized()
            }
            hashOutputs = Crypto.sha256sha256(data)
        } else if hashType.isSingle && index < outputs.count {
            hashOutputs = Crypto.sha256sha256(outputs[0].serialized())
        }

        let txIn = inputs[index]
        var data = Data()
        data += version
        data += hashPrevouts
        data += hashSequence
        data += txIn.previousOutput.hash
        data += txIn.previousOutput.index
        data += VarInt(prevOutScript.count).serialized()
        data += prevOutScript
        data += value
        data += txIn.sequence
        data += hashOutputs
        data += lockTime
        data += hashType.uint32
        return Crypto.sha256sha256(data)
    }
}
