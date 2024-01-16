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
    public let unspentTransactions: [UnspentTransaction]
    /// Transaction being signed.
    public let transaction: Transaction
    /// Signature Hash Helper
    public let sighashHelper: SignatureHashHelper

    /// List of signed inputs.
    private var signedInputs: [TransactionInput]
    /// Signed transaction
    private var signedTransaction: Transaction {
        return Transaction(
            version: transaction.version,
            inputs: signedInputs,
            outputs: transaction.outputs,
            lockTime: transaction.lockTime)
    }

    public init(unspentTransactions: [UnspentTransaction], transaction: Transaction, sighashHelper: SignatureHashHelper) {
        self.unspentTransactions = unspentTransactions
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
        for (i, unspentTransaction) in unspentTransactions.enumerated() {
            // Select key
            let utxo = unspentTransaction.output
            let pubkeyHash: Data = Script.getPublicKeyHash(from: utxo.lockingScript)

            guard let key = keys.first(where: { $0.publicKey().pubkeyHash == pubkeyHash }) else {
                throw TransactionSignerError.noKeyFound
            }

            let sighash: Data
            if isP2WPKH(utxo.lockingScript) {
                let signingScript = try! Script().append(.OP_DUP)
                    .append(.OP_HASH160)
                    .appendData(pubkeyHash)
                    .append(.OP_EQUALVERIFY)
                    .append(.OP_CHECKSIG).data
                sighash = transaction.hashForWitnessV0(index: i, prevOutScript: signingScript, value: utxo.value, hashType: sighashHelper.hashType)
            } else {

                // Sign transaction hash
                sighash = sighashHelper.createSignatureHash(of: transaction, for: utxo, inputIndex: i)
            }
            let signature: Data = try Crypto.sign(sighash, privateKey: key)
            let txin = signedInputs[i]
            let pubkey = key.publicKey()

            // Create Signature Script
            let sigWithHashType: Data = signature + [sighashHelper.hashType.uint8]
            let (finalScriptSig, finalScriptWitness) = prepareFinalScripts(input: unspentTransaction, signature: sigWithHashType, pubkey: pubkey.data)

            // Update TransactionInput
            signedInputs[i] = TransactionInput(previousOutput: txin.previousOutput, sequence: txin.sequence, signatureScript: finalScriptSig, witness: finalScriptWitness)
        }
        return signedTransaction
    }
}

public func isP2WPKH(_ data: Data) -> Bool {
    data.count == 22 &&
    data[0] == Op0().value &&
    data[1] == 0x14
}

public func isP2PKH(_ data: Data) -> Bool {
    data.count == 25 &&
    data[0] == OpDuplicate().value &&
    data[1] == OpHash160().value &&
    data[2] == 0x14 &&
    data[23] == OpEqualVerify().value &&
    data[24] == OpCheckSig().value
}

//function classifyScript(script: Buffer): ScriptType {
//  if (isP2WPKH(script)) return 'witnesspubkeyhash';
//  if (isP2PKH(script)) return 'pubkeyhash';
//  if (isP2MS(script)) return 'multisig';
//  if (isP2PK(script)) return 'pubkey';
//  return 'nonstandard';
//}
func prepareFinalScripts(input: UnspentTransaction, signature: Data, pubkey: Data) -> (Data?, [Data]?) {
    var finalScriptSig: Data? = nil
    var finalScriptWitness: [Data]? = nil

    if input.isSegwit {
        if input.isP2WSH {
            // TODO
        } else {
            finalScriptWitness = [signature, pubkey]
        }
        if input.isP2SH {
            // TODO
        }
    } else {
        if input.isP2SH {
            // TODO
        } else {
            finalScriptSig = try! Script().appendData(signature).appendData(pubkey).data
        }
    }
    return (finalScriptSig, finalScriptWitness)
}

func witnessStackToScriptWitness(witness: [Data]) -> Data {
    var data = Data()
    data += VarInt(witness.count).serialized()
    witness.forEach {
        data += VarInt($0.count).serialized()
        data += $0
    }
    return data
}
