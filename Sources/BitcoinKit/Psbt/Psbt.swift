//
//  Psbt.swift
//
//
//  Created by liugang zhang on 2024/4/10.
//

import Foundation

public class Psbt {
    public internal(set) var tx: Transaction
    public internal(set) var globalXpub: [GlobalXPub]?
    public internal(set) var unknownKeyVals: [PsbtKeyValue]?

    public internal(set) var inputs: [PsbtInputUpdate]
    public internal(set) var outputs: [PsbtOutputUpdate]

    public init(tx: Transaction = Transaction()) {
        self.tx = tx
        self.inputs = []
        self.outputs = []
    }

    public func addInput(prevOutput: TransactionOutPoint, sequence: UInt32 = UInt32.max, update: PsbtInputUpdate = PsbtInputUpdate()) {
        tx.addInput(.init(previousOutput: prevOutput, sequence: sequence))
        inputs.append(update)
    }

    public func addOutput(output: TransactionOutput, update: PsbtOutputUpdate = PsbtOutputUpdate()) {
        tx.addOutput(output)
        outputs.append(update)
    }

    public func signAllInputs(with pk: PrivateKey, sigHashType: SighashType? = nil) throws {
        for i in 0..<inputs.count {
            try signInput(with: pk, at: i, sigHashType: sigHashType)
        }
    }

    public func signInput(with pk: PrivateKey, at index: Int, sigHashType: SighashType?) throws {
        guard index < inputs.count else {
            throw PsbtError.indexOutOfBounds
        }
        if inputs[index].isTaprootInput {
            try _signTaprootInput(with: pk, at: index, sigHashType: sigHashType)
        } else {
            try _signInput(with: pk, at: index, sigHashType: sigHashType)
        }
    }

    private func _signInput(with pk: PrivateKey, at index: Int, sigHashType: SighashType?) throws {
        let (hash, _) = try getHashForSig(index: index)
        let signature: Data = try Crypto.sign(hash, privateKey: pk)
        /// TODO: sighashtype
        let partialSig = PartialSig(pubkey: pk.publicKey().data, signature: signature + [0x01])
        inputs[index].partialSig = [partialSig]
    }

    private func _signTaprootInput(with pk: PrivateKey, at index: Int, sigHashType: SighashType?) throws {
        let hashesForSig = try getTaprootHashesForSig(inputIndex: index, publicKey: pk.publicKey().data)
        let tapKeySig = try hashesForSig.filter { $0.leafHash == nil }
            .map { hash, _ in
                let signature = try Crypto.signSchnorr(hash, with: pk)
                return serializeTaprootSignature(sig: signature, sighashType: nil)
            }.first
        let tapScriptSig = try hashesForSig.filter { $0.leafHash != nil }
            .map { hash, leafHash in
                let signature = try Crypto.signSchnorr(hash, with: pk)
                return TapScriptSig(pubKey: toXOnly(pk.publicKey().data), signature: signature, leafHash: leafHash!)
            }
        if let tapKeySig {
            inputs[index].tapKeySig = tapKeySig
        }
        if !tapScriptSig.isEmpty {
            inputs[index].tapScriptSig = tapScriptSig
        }
    }

    public func finalizeAllInputs() throws {
        for i in 0..<inputs.count {
            try finalizeInput(index: i)
        }
    }

    public func finalizeInput(index: Int) throws {
        guard index < inputs.count else {
            throw PsbtError.indexOutOfBounds
        }
        if inputs[index].isTaprootInput {
            try _finalizeTaprootInput(index: index)
        } else {
            _finalizeInput(index: index)
        }
    }

    private func _finalizeInput(index: Int) {
        let (finalScriptSig, finalScriptWitness) = prepareFinalScripts(input: inputs[index], index: index)
        if let finalScriptSig {
            inputs[index].finalScriptSig = finalScriptSig
        }
        if let finalScriptWitness {
            inputs[index].finalScriptWitness = finalScriptWitness
        }
        inputs[index].clearFinalizedInput()
    }

    private func _finalizeTaprootInput(index: Int) throws {
        if inputs[index].witnessUtxo == nil {
            throw "Cannot finalize input \(index). Missing withness utxo."
        }
        if let tapKeySig = inputs[index].tapKeySig {
            let finalScriptWitness = witnessStackToScriptWitness(witness: P2tr.witnessFromSignature(tapKeySig))
            inputs[index].finalScriptWitness = finalScriptWitness
        } else {

        }

        inputs[index].clearFinalizedInput()
    }

    private func getHashForSig(index: Int) throws -> (hash: Data, sighashType: SighashType) {
        let input = inputs[index]
        /// TODO: sighashType
//        let sigHashType = input.sighashType ?? BTCSighashType.ALL
        let sigHashType = BTCSighashType.ALL
        let prevOut: TransactionOutput

        if let witnessUtxo = inputs[index].witnessUtxo {
            prevOut = witnessUtxo
        } else if let nonWitnessUtxo = inputs[index].nonWitnessUtxo {
            let _tx = Transaction.deserialize(nonWitnessUtxo)
            prevOut = _tx.outputs[Int(self.tx.inputs[index].previousOutput.index)]
        } else {
            throw PsbtError.utxoInputItemRequired
        }

        let isP2SH = isP2SHScript(prevOut.lockingScript)
        let isP2SHP2WSH = isP2SH && input.redeemScript != nil && isP2WSHScript(input.redeemScript!)
        let isP2WSH = isP2WSHScript(prevOut.lockingScript)

        if isP2SH && input.redeemScript == nil {
            throw PsbtError.p2shMissingRedeemScript
        }
        if (isP2WSH || isP2SHP2WSH) && input.witnessScript == nil {
            throw PsbtError.p2wshMissingWitnessScript
        }

        let meaningfulScript: Data = if isP2SHP2WSH {
            input.witnessScript!
        } else if isP2WSH {
            input.witnessScript!
        } else if isP2SH {
            input.redeemScript!
        } else {
            prevOut.lockingScript
        }

        let hash: Data
        if isP2SHP2WSH || isP2WSH {
            hash = tx.hashForWitnessV0(index: index, prevOutScript: meaningfulScript, value: prevOut.value, hashType: .BTC.ALL)
        } else if isP2WPKH(meaningfulScript) {
            let signingScript = P2pkh.init(hash: meaningfulScript[2...]).output
            hash = tx.hashForWitnessV0(index: index, prevOutScript: signingScript, value: prevOut.value, hashType: .BTC.ALL)
        } else {
            hash = tx.hashForSignature(index: index, prevOutScript: meaningfulScript, hashType: sigHashType)
        }
        return (hash, sigHashType)
    }

    func prepareFinalScripts(input: PsbtInputUpdate, index: Int) -> (Data?, Data?) {
        let isP2SH = input.redeemScript != nil
        let isP2WSH = input.witnessScript != nil
        let script: Data
        if let witnessScript = input.witnessScript {
            script = witnessScript
        } else if let redeemScript = input.redeemScript {
            script = redeemScript
        } else {
            if let nonWitnessUtxo = input.nonWitnessUtxo {
                let _tx = Transaction.deserialize(nonWitnessUtxo)
                script = _tx.outputs[Int(self.tx.inputs[index].previousOutput.index)].lockingScript
            } else if let witnessUtxo = input.witnessUtxo {
                script = witnessUtxo.lockingScript
            } else {
                script = Data()
            }
        }
        let sig = input.partialSig!
        let isSegwit = isP2WSH || isP2WPKH(script)

        let payment = getPayment(script: script)
        let payment_input = payment.inputFromSignature(sig)
        let payment_witness = payment.witnessFromSignature(sig)

        let p2wsh = isP2WSH ? P2Wsh(redeem: payment) : nil
        let p2wsh_witness = isP2WSH ? P2Wsh.witnessFrom(redeem: payment, input: payment_input, witness: payment_witness) : nil

        let p2sh = isP2SH ? P2sh(redeem: p2wsh ?? payment) : nil
        let p2sh_input = isP2SH ? P2sh.inputFrom(redeem: p2wsh ?? payment, input: isP2WSH ? .init() : payment_input) : nil

        var finalScriptSig: Data? = nil
        var finalScriptWitness: Data? = nil

        if isSegwit {
            if isP2WSH {
                finalScriptWitness = witnessStackToScriptWitness(witness: p2wsh_witness!)
            } else {
                finalScriptWitness = witnessStackToScriptWitness(witness: payment_witness)
            }
            if isP2SH {
                finalScriptSig = p2sh_input
            }
        } else {
            if isP2SH {
                finalScriptSig = p2sh_input
            } else {
                finalScriptSig = payment_input
            }
        }
        return (finalScriptSig, finalScriptWitness)
    }

    func getTaprootHashesForSig(inputIndex: Int, publicKey: Data, tapLeafHashToSign: Data? = nil) throws -> [(hash: Data, leafHash: Data?)] {
        let prevOuts = try inputs.map { try getScriptAndAmountFromUtxo(input: $0, index: inputIndex) }
        let signingScripts = prevOuts.map(\.script)
        let values = prevOuts.map(\.value)

        var hashes = [(hash: Data, leafHash: Data?)]()

        if inputs[inputIndex].tapInternalKey != nil && tapLeafHashToSign == nil {
            let script = signingScripts[inputIndex]
            let outputKey = isP2TR(script) ? script[2..<34] : Data()
            if toXOnly(publicKey) == outputKey {
                let tapKeyHash = tx.hashForWitnessV1(index: inputIndex, prevOutScripts: signingScripts, values: values, hashType: .BTC.ALL)
                hashes.append((tapKeyHash, nil))
            }
        }

        //        let tapLeafHashes = inputs[inputIndex].
        /// TODO:

        return hashes
    }

    func getScriptAndAmountFromUtxo(input: PsbtInputUpdate, index: Int) throws -> (script: Data, value: UInt64) {
        if let witnessUtxo = input.witnessUtxo {
            return (witnessUtxo.lockingScript, witnessUtxo.value)
        } else if let nonWitnessUtxo = input.nonWitnessUtxo {
            let _tx = Transaction.deserialize(nonWitnessUtxo)
            let out = _tx.outputs[Int(self.tx.inputs[index].previousOutput.index)]
            return (out.lockingScript, out.value)
        } else {
            throw PsbtError.utxoInputItemRequired
        }
    }

    func extractTransaction() -> Transaction {
        let tx = self.tx
        inputs.enumerated().forEach { offset, element in
            if let finalScriptSig = element.finalScriptSig {
                tx.inputs[offset].signatureScript = finalScriptSig
            }
            if let finalScriptWitness = element.finalScriptWitness {
                tx.inputs[offset].witness = scriptWitnessToWitnessStack(witness: finalScriptWitness)
            }
        }
        return tx
    }
}

func getPayment(script: Data) -> WitnessPaymentType {
    if isP2MS(script) {
        /// TODO: p2ms
        fatalError()
    } else if isP2PK(script) {
        try! P2pk(output: script)
    } else if isP2PKH(script) {
        try! P2pkh(output: script)
    } else if isP2WPKH(script) {
        try! P2wpkh(output: script)
    } else {
        fatalError()
    }
}

/// TODO: p2ms
func getSortedSigs(script: Data, partialSig: [PartialSig]) -> [Data] {
    return []
}


/// p2pkh input <==> [signature, pubkey] ,  witness: input ==> [empty]
///
/// p2pk input <==> signature, witness: input ==> [empty]
///
/// p2wpkh witness <==> [signature, pubkey] ,  input: witness ==> [empty]
///
/// p2tr witness <==> [signature],  witness ==> redeem
///
/// p2sh redeem.witness ==> witness , redeem <==> input, redeem ==> hash
///
/// p2wsh redeem <==> witness, input ==> [empty
