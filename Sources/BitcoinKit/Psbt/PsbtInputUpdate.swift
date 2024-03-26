//
//  PsbtInputUpdate.swift
//
//
//  Created by liugang zhang on 2024/3/25.
//

import Foundation

public class PsbtInputUpdate {
    var nonWitnessUtxo: Data?
    var witnessUtxo: TransactionOutput?
    var partialSig: [PartialSig]?
    var sighashType: UInt8?
    var redeemScript: Data?
    var witnessScript: Data?
    var bip32Derivation: [Bip32Derivation]?
    var finalScriptSig: Data?
    var finalScriptWitness: Data?
    var porCommitment: String?
    var tapKeySig: Data?
    var tapScriptSig: [TapScriptSig]?
    var tapLeafScript: [TapLeafScript]?
    var tapBip32Derivation: [TapBip32Derivation]?
    var tapInternalKey: Data?
    var tapMerkleRoot: Data?
    var unknownKeyVals: [Transaction.PsbtKeyValue]?

    public static func deserialize(from keyVals: [Transaction.PsbtKeyValue]) throws -> PsbtInputUpdate {
        let update = PsbtInputUpdate()
        for keyVal in keyVals {
            switch PsbtInputTypes(rawValue: keyVal.key[0]) {
            case .NON_WITNESS_UTXO:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .NON_WITNESS_UTXO)
                guard update.nonWitnessUtxo == nil else {
                    throw PsbtError.multipleInputKey(.NON_WITNESS_UTXO)
                }
                update.nonWitnessUtxo = keyVal.value
            case .WITNESS_UTXO:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .WITNESS_UTXO)
                guard update.witnessUtxo == nil else {
                    throw PsbtError.multipleInputKey(.WITNESS_UTXO)
                }
                update.witnessUtxo = TransactionOutput.deserialize(.init(keyVal.value))
            case .PARTIAL_SIG:
                if update.partialSig == nil {
                    update.partialSig = []
                }
                update.partialSig?.append(try decodePartialSig(keyVal: keyVal))
            case .SIGHASH_TYPE:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .SIGHASH_TYPE)
                guard update.sighashType == nil else {
                    throw PsbtError.multipleInputKey(.SIGHASH_TYPE)
                }
                update.sighashType = ByteStream(keyVal.value).read(UInt8.self)
            case .REDEEM_SCRIPT:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtInputTypes.REDEEM_SCRIPT)
                guard update.redeemScript == nil else {
                    throw PsbtError.multipleInputKey(.REDEEM_SCRIPT)
                }
                update.redeemScript = keyVal.value
            case .WITNESS_SCRIPT:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtInputTypes.WITNESS_SCRIPT)
                guard update.witnessScript == nil else {
                    throw PsbtError.multipleInputKey(.WITNESS_SCRIPT)
                }
                update.witnessScript = keyVal.value
            case .BIP32_DERIVATION:
                if update.bip32Derivation == nil {
                    update.bip32Derivation = []
                }
                update.bip32Derivation?.append(try decodeBip32Derivation(keyVal: keyVal))
            case .FINAL_SCRIPTSIG:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .FINAL_SCRIPTSIG)
                update.finalScriptSig = keyVal.value
            case .FINAL_SCRIPTWITNESS:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .FINAL_SCRIPTWITNESS)
                update.finalScriptWitness = keyVal.value
            case .POR_COMMITMENT:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .POR_COMMITMENT)
                update.porCommitment = String(data: keyVal.value, encoding: .utf8)
            case .TAP_KEY_SIG:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .TAP_KEY_SIG)
                guard keyVal.value.count == 64 || keyVal.value.count == 65 else {
                    throw PsbtError.invalidInputFormat(.TAP_KEY_SIG, keyVal.value)
                }
                update.tapKeySig = keyVal.value
            case .TAP_SCRIPT_SIG:
                if update.tapScriptSig == nil {
                    update.tapScriptSig = []
                }
                update.tapScriptSig?.append(try decodeTapScriptSig(keyVal: keyVal))
            case .TAP_LEAF_SCRIPT:
                if update.tapLeafScript == nil {
                    update.tapLeafScript = []
                }
                update.tapLeafScript?.append(try decodeTapLeafScript(keyVal: keyVal))
            case .TAP_BIP32_DERIVATION:
                if update.tapBip32Derivation == nil {
                    update.tapBip32Derivation = []
                }
                update.tapBip32Derivation?.append(try decodeTapBip32Derivation(keyVal: keyVal))
            case .TAP_INTERNAL_KEY:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtInputTypes.TAP_INTERNAL_KEY)
                guard keyVal.key.count == 1, keyVal.value.count == 32 else {
                    throw PsbtError.invalidInputFormat(.TAP_INTERNAL_KEY, keyVal.value)
                }
                update.tapInternalKey = keyVal.value
            case .TAP_MERKLE_ROOT:
                try checkKeyBuffer(keyBuf: keyVal.key, key: .TAP_MERKLE_ROOT)
                guard keyVal.key.count == 1, keyVal.value.count == 32 else {
                    throw PsbtError.invalidInputFormat(.TAP_MERKLE_ROOT, keyVal.value)
                }
                update.tapMerkleRoot = keyVal.value
            default:
                if update.unknownKeyVals == nil {
                    update.unknownKeyVals = []
                }
                update.unknownKeyVals?.append(keyVal)
            }
        }
        return update
    }

    //    public func serialized() -> Data {
    //    }
}

struct PartialSig {
    let pubkey: Data
    let signature: Data
}

struct TapLeafScript {
    let leafVersion: UInt8
    let script: Data
    let controlBlock: Data
}

struct Bip32Derivation {
    let masterFingerprint: Data
    let pubkey: Data
    let path: String
}

struct TapBip32Derivation {
    let masterFingerprint: Data
    let pubkey: Data
    let path: String
    let leafHashes: [Data]

    init(masterFingerprint: Data, pubkey: Data, path: String, leafHashes: [Data]) {
        self.masterFingerprint = masterFingerprint
        self.pubkey = pubkey
        self.path = path
        self.leafHashes = leafHashes
    }

    init(bip32Derivation: Bip32Derivation, leafHashes: [Data]) {
        self.masterFingerprint = bip32Derivation.masterFingerprint
        self.pubkey = bip32Derivation.pubkey
        self.path = bip32Derivation.path
        self.leafHashes = leafHashes
    }
}

func decodeNonWitnessUTXO(keyVal: Transaction.PsbtKeyValue) -> Data {
    keyVal.value
}

func decodeWitnessUTXO(keyVal: Transaction.PsbtKeyValue) -> TransactionOutput {
    TransactionOutput.deserialize(.init(keyVal.value))
}

func decodePartialSig(keyVal: Transaction.PsbtKeyValue) throws -> PartialSig {
    if (
        !(keyVal.key.count == 34 || keyVal.key.count == 66) ||
        ![2, 3, 4].contains(keyVal.key[1])
    ) {
        throw PsbtError.invalidInputFormat(.PARTIAL_SIG, keyVal.key)
    }
    let pubkey = keyVal.key[1...];
    return .init(pubkey: pubkey, signature: keyVal.value)

}

func decodeBip32Derivation(keyVal: Transaction.PsbtKeyValue, isValid: (Data) -> Bool = isValidDERKey) throws -> Bip32Derivation {
    let pubkey = keyVal.key[1...]
    guard isValid(pubkey), (keyVal.value.count / 4) % 1 == 0 else {
        throw PsbtError.invalidInputFormat(.BIP32_DERIVATION, keyVal.key)
    }
    var path = "m"
    for i in 0..<(keyVal.value.count / 4 - 1) {
        let val = ByteStream(keyVal.value[(i * 4 + 4 + keyVal.value.startIndex)...]).read(UInt32.self)
        let isHard = (val & 0x80000000) != 0
        let idx = val & 0x7fffffff
        path += "/"
        path += String(idx, radix: 10)
        isHard ? path +=  "'" : ()
    }
    return .init(masterFingerprint: keyVal.value[keyVal.value.startIndex ..< keyVal.value.startIndex + 4], pubkey: pubkey, path: path)
}

func decodeTapBip32Derivation(keyVal: Transaction.PsbtKeyValue) throws -> TapBip32Derivation {
    let mHashs = keyVal.value.to(type: VarInt.self)
    let mHashlens = mHashs.encodingLength
    let bip32Derivation = try decodeBip32Derivation(keyVal: (keyVal.key, keyVal.value[(mHashlens + UInt8(mHashs.underlyingValue) * 32)...]), isValid: isValidBIP340Key)
    var leafHashes = [Data]()
    var offset = mHashlens
    for _ in 0..<mHashs.underlyingValue {
        leafHashes.append(keyVal.value[offset ..< offset + 32])
        offset += 32
    }
    return .init(bip32Derivation: bip32Derivation, leafHashes: leafHashes)
}

func decodeTapScriptSig(keyVal: Transaction.PsbtKeyValue) throws -> TapScriptSig {
    guard keyVal.key.count == 65, keyVal.value.count != 64, keyVal.value.count != 65 else {
        throw PsbtError.invalidInputFormat(.TAP_SCRIPT_SIG, keyVal.key)
    }
    return .init(pubKey: keyVal.key[1..<33], signature: keyVal.key[33...], leafHash: keyVal.value)
}

func decodeTapLeafScript(keyVal: Transaction.PsbtKeyValue) throws -> TapLeafScript {
    guard (keyVal.key.count - 2) % 32 == 0 else {
        throw PsbtError.invalidInputFormat(.TAP_LEAF_SCRIPT, keyVal.key)
    }
    let leafVersion = keyVal.value.last!
    guard keyVal.key[1] & 0xfe == leafVersion else {
        throw PsbtError.invalidInputFormat(.TAP_LEAF_SCRIPT, keyVal.key)
    }
    return .init(leafVersion: leafVersion, script: keyVal.value[0 ..< -1], controlBlock: keyVal.key[1...])
}

func isValidDERKey(pubkey: Data) -> Bool {
    (pubkey.count == 33 && [2, 3].contains(pubkey.first)) ||
    (pubkey.count == 65 && 4 == pubkey.first);
}

func isValidBIP340Key(pubkey: Data) -> Bool {
    pubkey.count == 32
}
