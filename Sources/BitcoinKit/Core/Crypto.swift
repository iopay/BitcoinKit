//
//  Crypto.swift
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
import CryptoSwift
import ripemd160

public struct Crypto {
    public static func sha1(_ data: Data) -> Data {
        data.sha1()
    }

    public static func sha256(_ data: Data) -> Data {
        data.sha256()
    }

    public static func sha256sha256(_ data: Data) -> Data {
        data.sha256().sha256()
    }

    public static func ripemd160(_ data: Data) -> Data {
        Data(Ripemd160.digest(data.bytes))
    }

    public static func sha256ripemd160(_ data: Data) -> Data {
        ripemd160(sha256(data))
    }

    public static func hmacsha512(data: Data, key: Data) -> Data? {
        let hmac = HMAC(key: key.bytes, variant: .sha2(.sha512))
        guard let entropy = try? hmac.authenticate(data.bytes), entropy.count == 64 else { return nil }
        return Data(entropy)
    }

    public static func sign(_ data: Data, privateKey: PrivateKey) throws -> Data {
        return try _Crypto.signMessage(data, withPrivateKey: privateKey.data)
    }

    public static func signSchnorr(_ data: Data, with privateKey: PrivateKey) throws -> Data {
        return try _Crypto.signSchnorr(data, with: privateKey.data)
    }

    public static func verifySignature(_ signature: Data, message: Data, publicKey: Data) throws -> Bool {
        return try _Crypto.verifySignature(signature, message: message, publicKey: publicKey)
    }

    public static func verifySigData(for tx: Transaction, inputIndex: Int, utxo: TransactionOutput, sigData: Data, pubKeyData: Data) throws -> Bool {
        // Hash type is one byte tacked on to the end of the signature. So the signature shouldn't be empty.
        guard !sigData.isEmpty else {
            throw ScriptMachineError.error("SigData is empty.")
        }
        // Extract hash type from the last byte of the signature.
        let helper: SignatureHashHelper
        if let hashType = BCHSighashType(rawValue: sigData.last!) {
            helper = BCHSignatureHashHelper(hashType: hashType)
//        } else if let hashType = BTCSighashType(rawValue: sigData.last!) {
//            helper = BTCSignatureHashHelper(hashType: hashType)
        } else {
//            throw ScriptMachineError.error("Unknown sig hash type")
            helper = BTCSignatureHashHelper(hashType: BTCSighashType(rawValue: sigData.last!))
        }
        // Strip that last byte to have a pure signature.
        let sighash: Data = helper.createSignatureHash(of: tx, for: utxo, inputIndex: inputIndex)
        let signature: Data = sigData.dropLast()

        return try Crypto.verifySignature(signature, message: sighash, publicKey: pubKeyData)
    }

    public static func magicHash(message: String, prefix: String = "Bitcoin Signed Message:\n") -> Data {
        let messageBuffer = message.data(using: .utf8)!
        let prefixBuffer = prefix.data(using: .utf8)!
        let p1 = VarInt(prefixBuffer.count)
        let p2 = VarInt(messageBuffer.count)
        return (p1.serialized() + prefixBuffer + p2.serialized() + messageBuffer).sha256().sha256()
    }

    public static func signMessage(_ msg: String, privateKey: PrivateKey) -> String {
        let hash = magicHash(message: msg)
        let (signature, i) = _Crypto.signMessage2(hash, key: privateKey.data)
        return ([UInt8(i + 27 + 4)] + signature).toBase64()
    }

    static func bip0322Hash(_ message: String) -> Data {
        let tag = "BIP0322-signed-message"
        let tagHash = tag.data(using: .utf8)!.sha256()
        return (tagHash + tagHash + message.data(using: .utf8)!).sha256()
    }

    public static func signMessageOfBIP322Simple(_ message: String, address: String, network: Network, privateKey: PrivateKey) throws -> String {
        let address = try createAddress(from: address)
        if ![AddressType.P2WPKH, AddressType.P2TR].contains(address.type) {
            throw CryptoError.notSupportedAddress
        }
        let outputScript = address.script
        let xOnlyPubKey = privateKey.publicKey().xOnly

        let preHash = Data(hex: "0000000000000000000000000000000000000000000000000000000000000000")
        let scriptSig: Data = [0x00, 0x20] + bip0322Hash(message)
        let txToSpend = Transaction(version: 0, inputs: [
            .init(previousOutput: .init(hash: preHash, index: 0xffffffff), sequence: 0, signatureScript: scriptSig)
        ], outputs: [
            .init(value: 0, lockingScript: outputScript)
        ], lockTime: 0)
        let txToSpendHash = txToSpend.serialized().sha256().sha256()

        print("message: \(message), \(txToSpendHash.hex)")

        let psbt = Psbt()
        psbt.addInput(prevOutput: .init(hash: txToSpendHash, index: 0), sequence: 0, update: .init(witnessUtxo: .init(value: 0, lockingScript: outputScript), tapInternalKey: address.type == .P2TR ? xOnlyPubKey : nil))
        psbt.addOutput(output: .init(value: 0, lockingScript: Data([0x6a])))

        let key = if address.type == .P2TR {
            privateKey.tweaked
        } else {
            privateKey
        }
        try psbt.signAllInputs(with: key)
        let signedTx = psbt.extractTransaction()

        let length = VarInt(signedTx.inputs[0].witness.count)
        let res = signedTx.inputs[0].witness.map { VarInt($0.count).data + $0 }.reduce(length.data, { $0 + $1 })
        return res.base64EncodedString()
    }
}

public enum CryptoError: Error {
    case signFailed
    case noEnoughSpace
    case signatureParseFailed
    case publicKeyParseFailed
    case notSupportedAddress
}
