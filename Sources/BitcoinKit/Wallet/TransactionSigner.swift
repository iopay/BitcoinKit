//
//  TransactionSigner.swift
//  
//  Copyright © 2019 BitcoinKit developers
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

public enum TransactionSignerError: Error {
    case noKeyFound
}

/// Helper class that performs Bitcoin transaction signing.
/// ```
/// // Initialize a signer
/// let signer = TransactionSigner(unspentTransactions: unspentTransactions, transaction: transaction, sighashHelper: sighashHelper)
///
/// // Sign the unsigned transaction
/// let signedTx = signer.sign(with: privKeys)
/// ```
public final class TransactionSigner {
    /// Unspent transactions to be signed.
//    public let unspentTransactions: [UnspentTransaction]
    /// Transaction being signed.
    public let transaction: Transaction
    /// Signature Hash Helper
    public let sighashHelper: SignatureHashHelper

    /// List of signed inputs.
    private var signedInputs: [TransactionInput]
    /// Signed transaction
    private var signedTransaction: Transaction {
//        return Transaction(
//            version: transaction.version,
//            inputs: signedInputs,
//            outputs: transaction.outputs,
//            lockTime: transaction.lockTime)
        var tx = transaction
        tx.inputs = signedInputs
        return tx
    }

    public init(transaction: Transaction, sighashHelper: SignatureHashHelper) {
        self.transaction = transaction
        self.signedInputs = transaction.inputs
        self.sighashHelper = sighashHelper
    }

    /// Sign the transaction with keys of the unspent transactions
    ///
    /// - Parameters:
    ///   - keys: the private keys of the unspent transactions
    /// - Returns: A signed transaction. Error is thrown when the signing failed.
    public func sign(with keys: [PrivateKey]) throws -> Transaction {
        fatalError()
//        for (i, input) in transaction.inputs.enumerated() {
//            // Select key
//            let utxo = input.utxo//unspentTransaction.output
//            let txin = signedInputs[i]
//            let pubkeyHash: Data = Script.getPublicKeyHash(from: input.script)
////            print(utxo.lockingScript[2...].hex)
////            print(keys[0].publicKey().data.xOnly.hex)
//            
//            if input.isTaprootInput {
//                guard let key = keys.first(where: { k in
//                    P2tr(internalPubKey: k.publicKey().xOnly).output == input.update.witnessUtxo?.lockingScript
//                }) else {
//                    throw TransactionSignerError.noKeyFound
//                }
//                if input.update.finalScriptSig == nil || input.update.finalScriptWitness == nil && input.update.tapInternalKey == nil {
//                    input.update.tapInternalKey = key.publicKey().xOnly
//                }
//
//                let hashesForSig = transaction.getTaprootHashesForSig(inputs: transaction.inputs, inputIndex: i, publicKey: key.tweaked.publicKey().data)
//                let tapKeySig = try hashesForSig.filter { $0.leafHash == nil }
//                    .map { hash, _ in
//                        let signature = try Crypto.signSchnorr(hash, with: key.tweaked)
//                        return serializeTaprootSignature(sig: signature, sighashType: nil)
//                    }.first
//                let tapScriptSig = try hashesForSig.filter { $0.leafHash != nil }
//                    .map { hash, leafHash in
//                        let signature = try Crypto.signSchnorr(hash, with: key.tweaked)
//                        return TapScriptSig(pubKey: toXOnly(key.publicKey().data), signature: signature, leafHash: leafHash!)
//                    }
//                /// TODO: tapScriptSig
//                let finalScriptWitness: [Data]
//                if let tapKeySig {
//                    input.update.tapKeySig = tapKeySig
////                    let witness = p2trWitness(script: utxo.lockingScript, signature: tapKeySig)
////                    finalScriptWitness = witnessStackToScriptWitness(witness: witness)
//                    finalScriptWitness = p2trWitness(script: utxo.lockingScript, signature: tapKeySig)
//                    input.update.finalScriptWitness = witnessStackToScriptWitness(witness: finalScriptWitness)
//                } else if !tapScriptSig.isEmpty {
//                    input.update.tapScriptSig = tapScriptSig
//                    finalScriptWitness = tapScriptFinalizer()
//                } else {
//                    finalScriptWitness = []
//                }
//
//                var copy = input
//                copy.witness = finalScriptWitness
//                copy.update.clearFinalizedInput()
//                signedInputs[i] = copy
////                signedInputs[i] = TransactionInput(previousOutput: txin.previousOutput, sequence: txin.sequence, signatureScript: nil, witness: finalScriptWitness)
//            } else {
//                guard let key = keys.first(where: { $0.publicKey().pubkeyHash == pubkeyHash }) else {
//                    throw TransactionSignerError.noKeyFound
//                }
//
//                let sighash: Data
//                if isP2WPKH(input.script) {
//                    let signingScript = try! Script().append(.OP_DUP)
//                        .append(.OP_HASH160)
//                        .appendData(pubkeyHash)
//                        .append(.OP_EQUALVERIFY)
//                        .append(.OP_CHECKSIG).data
//                    /// p2sh-p2wpkh, p2wpkh
//                    sighash = transaction.hashForWitnessV0(index: i, prevOutScript: signingScript, value: utxo.value, hashType: sighashHelper.hashType)
//                } else {
//
//                    // Sign transaction hash, p2pkh
//                    sighash = sighashHelper.createSignatureHash(of: transaction, for: utxo, inputIndex: i)
//                }
//                let signature: Data = try Crypto.sign(sighash, privateKey: key)
//                
//                // Create Signature Script
//                let sigWithHashType: Data = signature + [sighashHelper.hashType.uint8]
//
//                input.update.partialSig = [.init(pubkey: key.publicKey().data, signature: sigWithHashType)]
//
//                let (finalScriptSig, finalScriptWitness) = prepareFinalScripts(input: input, signature: sigWithHashType, pubkey: key.publicKey().data)
//
//                // Update TransactionInput
////                signedInputs[i] = TransactionInput(previousOutput: txin.previousOutput, sequence: txin.sequence, signatureScript: finalScriptSig, witness: finalScriptWitness)
//                var copy = input
//                copy.signatureScript = finalScriptSig ?? Data()
//                copy.witness = finalScriptWitness ?? []
//                signedInputs[i] = copy
//            }
//        }
//
////        for input in transaction.inputs {
////            if input.isTaprootInput {
////
////            } else {
////                let (finalScriptSig, finalScriptWitness) = prepareFinalScripts(input: input, signature: sigWithHashType, pubkey: key.publicKey().data)
////            }
////        }
//        return signedTransaction
    }
}

//function classifyScript(script: Buffer): ScriptType {
//  if (isP2WPKH(script)) return 'witnesspubkeyhash';
//  if (isP2PKH(script)) return 'pubkeyhash';
//  if (isP2MS(script)) return 'multisig';
//  if (isP2PK(script)) return 'pubkey';
//  return 'nonstandard';
//}
//func prepareFinalScripts(input: TransactionInput, signature: Data, pubkey: Data) -> (Data?, [Data]?) {
//    var finalScriptSig: Data? = nil
//    var finalScriptWitness: [Data]? = nil
//
//    if input.isSegwit {
//        if input.isP2WSH {
//            // TODO
//        } else {
//            finalScriptWitness = [signature, pubkey]
//        }
//        if input.isP2SH {
//            finalScriptSig = try! Script().appendData(input.script).data
//        }
//    } else {
//        if input.isP2SH {
//            finalScriptSig = try! Script().appendData(input.script).data
//        } else {
//            finalScriptSig = try! Script().appendData(signature).appendData(pubkey).data
//        }
//    }
//    return (finalScriptSig, finalScriptWitness)
//}

//
//func getTaprootHashesForSig(inputs: [UnspentTransaction], inputIndex: Int, publicKey: Data, tapLeafHashToSign: Data? = nil) {
//    let prevOuts = inputs.map { ($0.output.value, $0.script ) }
//    let signingScripts = inputs.map { $0.script }
//    let values = inputs.map { $0.output.value }
//
//    if inputs[inputIndex].output.tapInternalKey != nil {
//        let script = signingScripts[inputIndex]
//        let outputKey = isP2TR(script) ? script[2..<34] : Data()
//        if toXOnly(publicKey) == outputKey {
//
//        }
//    }
//}

func serializeTaprootSignature(sig: Data, sighashType: UInt8?) -> Data {
    let sighashTypeByte = (sighashType != nil) ? Data([sighashType!]) : Data()
    return sig + sighashTypeByte
}


/// TODO
func p2trWitness(script: Data, signature: Data) -> [Data] {
    return [signature]
}

/// TODO
func tapScriptFinalizer() -> [Data] {
    fatalError()
}
