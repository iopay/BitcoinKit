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

public struct GlobalXPub {
    public let extendedPubkey: Data
    public let masterFingerprint: Data
    public let path: String;
}

/// tx describes a bitcoin transaction, in reply to getdata
public struct Transaction {
    private static let ADVANCED_TRANSACTION_MARKER: UInt8 = 0x00
    private static let ADVANCED_TRANSACTION_FLAG: UInt8 = 0x01
    /// Transaction data format version (note, this is signed)
    public let version: UInt32
    /// If present, always 0001, and indicates the presence of witness data
    // public let flag: UInt16 // If present, always 0001, and indicates the presence of witness data
    /// Number of Transaction inputs (never zero)
    public var txInCount: VarInt {
        return VarInt(inputs.count)
    }
    /// A list of 1 or more transaction inputs or sources for coins
    public var inputs: [TransactionInput]
    /// Number of Transaction outputs
    public var txOutCount: VarInt {
        return VarInt(outputs.count)
    }
    /// A list of 1 or more transaction outputs or destinations for coins
    public var outputs: [TransactionOutput]
    /// A list of witnesses, one for each input; omitted if flag is omitted above
    // public let witnesses: [TransactionWitness] // A list of witnesses, one for each input; omitted if flag is omitted above
    /// The block number or timestamp at which this transaction is unlocked:
    public let lockTime: UInt32

    public var globalXpub: [GlobalXPub]?
    public var unknownKeyVals: [Transaction.PsbtKeyValue]?

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
            data += Self.ADVANCED_TRANSACTION_MARKER
            data += Self.ADVANCED_TRANSACTION_FLAG
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

        let maker = byteStream.read(UInt8.self)
        let flag = byteStream.read(UInt8.self)
        let hasWitness = maker == Self.ADVANCED_TRANSACTION_MARKER && flag == Self.ADVANCED_TRANSACTION_FLAG
        if !hasWitness {
            byteStream.advance(by: -2)
        }

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

        if hasWitness {
            for i in 0..<Int(txInCount.underlyingValue) {
                inputs[i].witness = byteStream.read([Data].self)
            }
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

    func hashForWitnessV1(index: Int, prevOutScripts: [Data], values: [UInt64], hashType: SighashType, leafHash: Data? = nil, annex: Data? = nil) -> Data {
        precondition(prevOutScripts.count == inputs.count)
        precondition(values.count == inputs.count)

        var hashPrevouts = Data()
        var hashAmounts = Data()
        var hashScriptPubKeys = Data()
        var hashSequences = Data()
        var hashOutputs = Data()

        if !hashType.inputIsAnyoneCanPay {
//            var data = Data(capacity: 36 * inputs.count)

            hashPrevouts = Data(inputs.flatMap({ $0.previousOutput.serialized() })).sha256()

            var data = Data(capacity: 8 * inputs.count)
            values.forEach { data += $0 }
            hashAmounts = data.sha256()

            data = Data(capacity: prevOutScripts.map { $0.count }.reduce(0, +))
            prevOutScripts.forEach { script in
                data += VarInt(script.count).serialized()
                data += script
            }
            hashScriptPubKeys = data.sha256()

            data = Data(capacity: 4 * inputs.count)
            inputs.forEach { input in
                data += input.sequence
            }
            hashSequences = data.sha256()
        }

        if !(hashType.isNone || hashType.isSingle) {
            hashOutputs = Data(outputs.flatMap({ $0.serialized() })).sha256()
        } else if hashType.isSingle && index < outputs.count {
            let out = outputs[index]
            hashOutputs = out.serialized().sha256()
        }

        let spendType: UInt8 = ((leafHash != nil) ? 2 : 0) + ((annex != nil) ? 1 : 0)
        let sigMsgSize = 174 -
            (hashType.inputIsAnyoneCanPay ? 49 : 0) -
            (hashType.isNone ? 32 : 0) +
            ((annex != nil) ? 32 : 0) +
            ((leafHash != nil) ? 37 : 0)

        var data = Data()
        data += UInt8(0)//hashType.uint8
        data += version
        data += lockTime
        data += hashPrevouts
        data += hashAmounts
        data += hashScriptPubKeys
        data += hashSequences
        if !(hashType.isNone || hashType.isSingle) {
            data += hashOutputs
        }
        data += spendType

        if hashType.inputIsAnyoneCanPay {
            let input = inputs[index]
            data += input.previousOutput.serialized()
            data += values[index]
            data += VarInt(prevOutScripts[index].count).serialized()
            data += prevOutScripts[index]
            data += input.sequence
        } else {
            data += UInt32(index)
        }

        if annex != nil {
            data += (VarInt(annex!.count).serialized() + annex!).sha256()
        }

        if hashType.isSingle {
            data += hashOutputs
        }

        if leafHash != nil {
            data += leafHash!
            data += UInt8(0)
            data += UInt32(0xffffffff)
        }

        return taggedHash(.TapSighash, data: [0x00] + data)
    }

    func getTaprootHashesForSig(inputs: [UnspentTransaction], inputIndex: Int, publicKey: Data, tapLeafHashToSign: Data? = nil) -> [(hash: Data, leafHash: Data?)] {
        let prevOuts = inputs.map { ($0.output.value, $0.script ) }
        let signingScripts = inputs.map { $0.script }
        let values = inputs.map { $0.output.value }

        var hashes = [(hash: Data, leafHash: Data?)]()

        if inputs[inputIndex].tapInternalKey != nil {
            let script = signingScripts[inputIndex]
            let outputKey = isP2TR(script) ? script[2..<34] : Data()
            if toXOnly(publicKey) == outputKey {
                let tapKeyHash = hashForWitnessV1(index: inputIndex, prevOutScripts: signingScripts, values: values, hashType: .BTC.ALL)
                hashes.append((tapKeyHash, nil))
            }
        }

//        let tapLeafHashes = inputs[inputIndex].
        /// TODO:

        return hashes
    }

}

extension Transaction {
    public typealias PsbtKeyValue = (key: Data, value: Data)

    static func fromPsbtHex(_ hex: String) {

    }

    static func fromPsbtHex(_ buffer: Data) throws -> Transaction {
        let byteStream = ByteStream(buffer)

        guard byteStream.read(UInt32.self, bigEndian: true) == 0x70736274, byteStream.read(UInt8.self) == 0xff else {
            throw PsbtError.invalidMagicNumber
        }

        var globalKeyIndex = [String: Bool]()
        var globalMapKeyVals = [PsbtKeyValue]()
        while try byteStream.read(UInt8.self) != 0 {
            byteStream.advance(by: -1)

            let key = try byteStream.read(Data.self)
            let value = try byteStream.read(Data.self)
            if globalKeyIndex[key.hex] == true {
                throw PsbtError.keyMustUnique(key.hex)
            }
            globalKeyIndex[key.hex] = true
            globalMapKeyVals.append((key, value))
        }

        let unsignedTxMaps = globalMapKeyVals.filter { $0.key.bytes[0] == PsbtGlobalTypes.UNSIGNED_TX.rawValue }
        guard unsignedTxMaps.count == 1 else {
            throw PsbtError.multiUnsignedTx
        }

        var unsigned = Transaction.deserialize(unsignedTxMaps[0].value)

        var inputKeyVals = [[PsbtKeyValue]]()
        var outputKeyVals = [[PsbtKeyValue]]()

        for _ in 0..<unsigned.inputs.count {
            var inputKeyIndex = [String: Bool]()
            var input = [PsbtKeyValue]()
            while try byteStream.read(UInt8.self) != 0 {
                byteStream.advance(by: -1)

                let key = try byteStream.read(Data.self)
                let value = try byteStream.read(Data.self)

                if inputKeyIndex[key.hex] == true {
                    throw PsbtError.keyMustUnique(key.hex)
                }
                inputKeyIndex[key.hex] = true
                input.append((key, value))
            }
            inputKeyVals.append(input)
        }

        for _ in 0..<unsigned.outputs.count {
            var outputKeyIndex = [String: Bool]()
            var output = [PsbtKeyValue]()
            while try byteStream.read(UInt8.self) != 0 {
                byteStream.advance(by: -1)

                let key = try byteStream.read(Data.self)
                let value = try byteStream.read(Data.self)

                if outputKeyIndex[key.hex] == true {
                    throw PsbtError.keyMustUnique(key.hex)
                }
                outputKeyIndex[key.hex] = true
                output.append((key, value))
            }
            outputKeyVals.append(output)
        }

        var txExist = false
        for keyVals in globalMapKeyVals {
            switch keyVals.key[0] {
            case PsbtGlobalTypes.UNSIGNED_TX.rawValue:
                guard !txExist else {
                    throw PsbtError.multiUnsignedTx
                }
                txExist = true
            case PsbtGlobalTypes.GLOBAL_XPUB.rawValue:
                if unsigned.globalXpub == nil {
                    unsigned.globalXpub = []
                }
                unsigned.globalXpub?.append(try decodeGlobalXpub(keyVal: keyVals))
            default:
                if unsigned.unknownKeyVals == nil {
                    unsigned.unknownKeyVals = []
                }
                unsigned.unknownKeyVals?.append(keyVals)
            }
        }

//        var inputs = [TransactionInput]()
        for i in 0..<unsigned.inputs.count {
            unsigned.inputs[i].update = try PsbtInputUpdate.deserialize(from: inputKeyVals[i])
//            for keyVals in inputKeyVals[i] {
//                switch keyVals.key[0] {
//                case PsbtInputTypes.NON_WITNESS_UTXO.rawValue:
//                    ()
//                default:
//                    ()
//                }
//            }
        }

//        let inputs = try inputKeyVals.map { try PsbtInputUpdate.deserialize(from: $0) }
//        let outpus = try outputKeyVals.map { try PsbtOutputUpdate.deserialize(from: $0) }

        for i in 0..<unsigned.outputs.count {
            unsigned.outputs[i].update = try PsbtOutputUpdate.deserialize(from: outputKeyVals[i])
//            for keyVals in outputKeyVals[i] {
//                switch keyVals.key[0] {
//                case PsbtOutputTypes.REDEEM_SCRIPT.rawValue:
//                    ()
//                default:
//                    ()
//                }
//            }
        }

//        fatalError()
        return unsigned
    }
}

func decodeGlobalXpub(keyVal: Transaction.PsbtKeyValue) throws -> GlobalXPub {
        let pubkey = keyVal.key[1...]
    guard keyVal.key.count == 79, [2, 3].contains(keyVal.key[46]), (keyVal.value.count / 4) % 1 == 0 else {
            throw PsbtError.unexpectedEnd
        }
//        let masterFingerprint = keyVal.value[0..<4]
        var path = "m"
        for i in 0..<(keyVal.value.count / 4 - 1) {
            let val = ByteStream(keyVal.value[(i * 4 + 4 + keyVal.value.startIndex)...]).read(UInt32.self)
            let isHard = (val & 0x80000000) != 0
            let idx = val & 0x7fffffff
            path += "/"
            path += String(idx, radix: 10)
            isHard ? path +=  "'" : ()
        }
    return .init(extendedPubkey: keyVal.key[1...], masterFingerprint: keyVal.value[0..<4], path: path)
    }


