//
//  Transaction+Hash.swift
//
//
//  Created by liugang zhang on 2024/5/10.
//

import Foundation

extension Transaction {
    static let ONE = Data(repeating: 1, count: 1) + Data(repeating: 0, count: 31)

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

    func hashForWitnessV1(index: Int, prevOutScripts: [Data], values: [UInt64], hashType: BTCSighashType, leafHash: Data? = nil, annex: Data? = nil) -> Data {
        precondition(prevOutScripts.count == inputs.count)
        precondition(values.count == inputs.count)

        var hashPrevouts = Data()
        var hashAmounts = Data()
        var hashScriptPubKeys = Data()
        var hashSequences = Data()
        var hashOutputs = Data()

//        let outputType: BTCSighashType = hashType == .DEFAULT ? .ALL : hashType.rawValue &
        let outputType = hashType.rawValue == 0 ? BTCSighashType.ALL : hashType

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

        if !(outputType.isNone || outputType.isSingle) {
            hashOutputs = Data(outputs.flatMap({ $0.serialized() })).sha256()
        } else if outputType.isSingle && index < outputs.count {
            let out = outputs[index]
            hashOutputs = out.serialized().sha256()
        }

        let spendType: UInt8 = ((leafHash != nil) ? 2 : 0) + ((annex != nil) ? 1 : 0)
//        let sigMsgSize = 174 -
//        (hashType.inputIsAnyoneCanPay ? 49 : 0) -
//        (hashType.isNone ? 32 : 0) +
//        ((annex != nil) ? 32 : 0) +
//        ((leafHash != nil) ? 37 : 0)

        var data = Data()
        data += hashType.uint8
        data += version
        data += lockTime
        data += hashPrevouts
        data += hashAmounts
        data += hashScriptPubKeys
        data += hashSequences
        if !(outputType.isNone || outputType.isSingle) {
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

        if let annex {
            data += (VarInt(annex.count).serialized() + annex).sha256()
        }

        if outputType.isSingle {
            data += hashOutputs
        }

        if let leafHash {
            data += leafHash
            data += UInt8(0)
            data += UInt32(0xffffffff)
        }

        return taggedHash(.TapSighash, data: [0x00] + data)
    }

    func hashForSignature(
        index: Int,
        prevOutScript: Data,
        hashType: SighashType
    ) -> Data {
        guard index < inputs.count else {
            return Self.ONE
        }
        let ourScript = try! Script(data: prevOutScript)!.deleteOccurrences(of: .OP_CODESEPARATOR).data
        var ins = self.inputs
        var outs = self.outputs

        if hashType.isNone {
            ins.enumerated().forEach { idx, ele in
                if idx == index {
                    ins[idx].sequence = 0
                }
            }
        } else if hashType.isSingle {
            if index >= outs.count {
                return Self.ONE
            }
            let myOutput = self.outputs[index]
            outs = Array(repeating: TransactionOutput(), count: index) + [myOutput]

            (0..<ins.count).forEach { idx in
                if idx == index {
                    ins[idx].sequence = 0
                }
            }
        }

        if hashType.isAnyoneCanPay {
            ins = [ins[index]]
            ins[0].signatureScript = ourScript
        } else {
            (0..<ins.count).forEach { idx in
                if idx == index {
                    ins[idx].signatureScript = ourScript
                } else {
                    ins[idx].signatureScript = Data()
                }
            }
        }

        var data: Data = Transaction(version: version, inputs: ins, outputs: outs, lockTime: lockTime).serialized()
        data += hashType.uint32
        return Crypto.sha256sha256(data)
    }
}
