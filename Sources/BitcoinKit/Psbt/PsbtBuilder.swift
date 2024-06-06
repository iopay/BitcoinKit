//
//  PsbtBuilder.swift
//
//
//  Created by liugang zhang on 2024/5/31.
//

import Foundation

public protocol UtxoType {
    var tx: Data { get }
    var index: UInt32 { get }
    var amount: UInt64 { get set }
    var addressType: AddressType { get }
    var script: Data { get set }
    var pubKey: Data { get set }
}

extension UtxoType {
    var txInput: (TransactionInput, PsbtInputUpdate) {
        let input = TransactionInput(previousOutput: .init(hash: tx, index: index))
        let update = PsbtInputUpdate(witnessUtxo: TransactionOutput(value: amount, lockingScript: script))
        if addressType == .P2TR {
            update.tapInternalKey = pubKey.xOnly
        } else if addressType == .P2SH(.P2WPKH) {
            let redeem = P2wpkh(pubkey: pubKey)
            update.redeemScript = redeem.output
        }
        return (input, update)
    }
}

extension PrivateKey {
    func toAddress(type: AddressType) -> Address {
        switch type {
        case .P2PKH: publicKey().legacy()
        case .P2WPKH: publicKey().nativeSegwit()
        case .P2SH(_): publicKey().nestedSegwit()
        case .P2TR: publicKey().taproot()
        default: fatalError()
        }
    }
}

public class PsbtBuilder {
    static let UTXO_DUST: UInt64 = 546

    public enum BuilderError: Error {
        case illegalParameter
        case insufficientUTXO
    }

    private class Transaction {
        private var changeOutputIndex = -1
        private var cacheNetworkFee: Double = 0
        private var cacheUtxos = [UtxoType]()
        private var cacheToSignInputs = [UserToSignInput]()

        var feeRate: Double = 1
        var enableRBF: Bool = true

        var utxos = [UtxoType]()
        var inputs = [(TransactionInput, PsbtInputUpdate)]()
        var outputs = [TransactionOutput]()

        init() { }

        init(feeRate: Double, enableRBF: Bool) {
            self.feeRate = feeRate
            self.enableRBF = enableRBF
        }

        var totalInput: UInt64 {
            inputs.reduce(0, { $0 + $1.1.witnessUtxo!.value })
        }

        var totalOutput: UInt64 {
            outputs.reduce(0, { $0 + $1.value })
        }

        func addInput(utxo: UtxoType) {
            utxos.append(utxo)
            inputs.append(utxo.txInput)
        }

        func removeLastInput() {
            utxos.removeLast()
            inputs.removeLast()
        }

        func addOutput(script: Data, amount: UInt64) {
            outputs.append(.init(value: amount, lockingScript: script))
        }

        func removeChangeOutput() {
            outputs.remove(at: changeOutputIndex)
            changeOutputIndex = -1
        }

        func addChangeOutput(amount: UInt64, address: Address) {
            outputs.append(.init(value: amount, lockingScript: address.script))
            changeOutputIndex = outputs.count - 1
        }

        func addSufficientUtxosForFee(utxos: [UtxoType], changeAddress: Address) throws -> [UserToSignInput] {
            cacheUtxos = utxos

            var dummy = utxos[0]
            dummy.amount = 2100000000000000
            addInput(utxo: dummy)
            addChangeOutput(amount: 0, address: changeAddress)

            let networkFee = try calcNetworkFee()
            let dummySize = utxos[0].addressType.virtualSize
            cacheNetworkFee = networkFee - dummySize * feeRate

            removeLastInput()
            try selectBtcUtxos()

            let changeAmount = totalInput - totalOutput - UInt64(ceil(cacheNetworkFee))
            removeChangeOutput()
            if changeAmount > PsbtBuilder.UTXO_DUST {
                addChangeOutput(amount: changeAmount, address: changeAddress)
            }

            return cacheToSignInputs
        }

        func calcNetworkFee() throws -> Double {
            let psbt = try createEstimatePsbt()
            let vsize = psbt.extractTransaction().virtualSize
            return ceil(Double(vsize) * feeRate)
        }

        func selectBtcUtxos() throws {
            let totalIn = Double(totalInput)
            let totalOut = Double(totalOutput) + cacheNetworkFee
            if totalIn < totalOut {
                let (selected, remaining) = selectUtxo(for: totalOut - totalIn)
                if selected.isEmpty {
                    throw BuilderError.insufficientUTXO
                }
                selected.forEach { utxo in
                    addInput(utxo: utxo)
                    cacheToSignInputs.append(.init(index: inputs.count - 1, publicKey: utxo.pubKey.hex))
                    cacheNetworkFee += utxo.addressType.virtualSize * feeRate
                }
                cacheUtxos = remaining
                try selectBtcUtxos()
            }
        }

        func selectUtxo(for amount: Double) -> (selected: [UtxoType], remaining: [UtxoType]) {
            var selected = [UtxoType]()
            var remaining = [UtxoType]()
            var totalAmount: Double = 0
            for utxo in cacheUtxos {
                if totalAmount < amount {
                    totalAmount += Double(utxo.amount)
                    selected.append(utxo)
                } else {
                    remaining.append(utxo)
                }
            }
            return (selected, remaining)
        }

        func createEstimatePsbt() throws -> Psbt {
            let estimateKey = PrivateKey()
            let script = estimateKey.toAddress(type: utxos[0].addressType).script

            let tx = clone()

            var newArray = [UtxoType]()
            for i in 0..<tx.utxos.count {
                var copy = tx.utxos[i]
                copy.script = script
                copy.pubKey = estimateKey.publicKey().data
                newArray.append(copy)
            }
            tx.inputs = newArray.map { $0.txInput }

            let psbt = tx.toPsbt()
            let toSignInputs = tx.inputs.enumerated().map { idx, input in
                return UserToSignInput(index: idx, publicKey: estimateKey.publicKey().data.hex)
            }

            try estimateKey.sign(psbt, options: toSignInputs)
            return psbt
        }

        func toPsbt() -> Psbt {
            let psbt = Psbt()
            inputs.forEach { input in
                psbt.addInput(prevOutput: input.0.previousOutput, sequence: enableRBF ? 0xfffffffd : 0xffffffff, update: input.1)
            }
            outputs.forEach { output in
                psbt.addOutput(output: output)
            }
            return psbt
        }

        func clone() -> Transaction {
            let tx = Transaction(feeRate: feeRate, enableRBF: enableRBF)
            tx.utxos = utxos.map { $0 }
            tx.inputs = inputs.map { $0 }
            tx.outputs = outputs.map { $0 }
            return tx
        }
    }

    public static func build(_ from: [UtxoType], to: [Address], toAmount: [UInt64], change: Address, feeRate: Double, enableRBF: Bool = true) throws -> (Psbt, [UserToSignInput]) {
        guard to.count == toAmount.count, from.first != nil else {
            throw BuilderError.illegalParameter
        }

        let tx = Transaction(feeRate: feeRate, enableRBF: enableRBF)

        for i in 0..<to.count {
            tx.outputs.append(.init(value: toAmount[i], address: to[i]))
        }

        let toSignInputs = try tx.addSufficientUtxosForFee(utxos: from, changeAddress: change)

        return (tx.toPsbt(), toSignInputs)
    }

    public static func buildAll(_ from: [UtxoType], to: Address, feeRate: Double, enableRBF: Bool = true) throws -> (Psbt, [UserToSignInput]) {
        guard from.first != nil else {
            throw BuilderError.illegalParameter
        }

        let tx = Transaction(feeRate: feeRate, enableRBF: enableRBF)
        tx.addOutput(script: to.script, amount: UTXO_DUST)

        var toSignInputs = [UserToSignInput]()
        from.enumerated().forEach { index, utxo in
            tx.addInput(utxo: utxo)
            toSignInputs.append(.init(index: index, publicKey: utxo.pubKey.hex))
        }

        let fee = try tx.calcNetworkFee()
        let unspent = tx.totalInput - UInt64(fee)
        if unspent < UTXO_DUST {
            throw BuilderError.insufficientUTXO
        }
        tx.outputs[0] = .init(value: unspent, lockingScript: to.script)

        return (tx.toPsbt(), toSignInputs)
    }
}
