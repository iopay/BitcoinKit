//
//  PsbtOutputUpdate.swift
//
//
//  Created by liugang zhang on 2024/3/25.
//

import Foundation

public class PsbtOutputUpdate {
    var redeemScript: Data?
    var witnessScript: Data?
    var bip32Derivation: [Bip32Derivation]?
    var tapInternalKey: Data?
    var tapTree: TapTree?
    var tapBip32Derivation: [TapBip32Derivation]?
    var unknownKeyVals: [Transaction.PsbtKeyValue]?

    public static func deserialize(from keyVals: [Transaction.PsbtKeyValue]) throws -> PsbtOutputUpdate {
        let update = PsbtOutputUpdate()
        for keyVal in keyVals {
            switch PsbtOutputTypes(rawValue: keyVal.key[0]) {
            case .REDEEM_SCRIPT:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtOutputTypes.REDEEM_SCRIPT)
                guard update.redeemScript == nil else {
                    throw PsbtError.multipleOutputKey(.REDEEM_SCRIPT)
                }
                update.redeemScript = keyVal.value
            case .WITNESS_SCRIPT:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtOutputTypes.WITNESS_SCRIPT)
                guard update.witnessScript == nil else {
                    throw PsbtError.multipleOutputKey(.WITNESS_SCRIPT)
                }
                update.witnessScript = keyVal.value
            case .BIP32_DERIVATION:
                if update.bip32Derivation == nil {
                    update.bip32Derivation = []
                }
                update.bip32Derivation?.append(try decodeBip32Derivation(keyVal: keyVal))
            case .TAP_INTERNAL_KEY:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtOutputTypes.TAP_INTERNAL_KEY)
                guard keyVal.key.count == 1, keyVal.value.count == 32 else {
                    throw PsbtError.invalidInputFormat(.TAP_INTERNAL_KEY, keyVal.value)
                }
                update.tapInternalKey = keyVal.value
            case .TAP_TREE:
                try checkKeyBuffer(keyBuf: keyVal.key, key: PsbtOutputTypes.TAP_TREE)
                update.tapTree = try decodeTapTree(keyVal: keyVal)
            case .TAP_BIP32_DERIVATION:
                if update.tapBip32Derivation == nil {
                    update.tapBip32Derivation = []
                }
                update.tapBip32Derivation?.append(try decodeTapBip32Derivation(keyVal: keyVal))
            default:
                if update.unknownKeyVals == nil {
                    update.unknownKeyVals = []
                }
                update.unknownKeyVals?.append(keyVal)
            }
        }
        return update
    }

}

struct TapLeaf {
    let leafVersion: UInt8
    let script: Data
    let depth: UInt8
}

struct TapTree {
    let leaves: [TapLeaf]
}

func decodeTapTree(keyVal: Transaction.PsbtKeyValue) throws -> TapTree {
    var data = [TapLeaf]()
    var offset = 0
    let byteStream = ByteStream(keyVal.value)
//    while 0 < keyVal.value.count {
//        let depth = keyVal.value[offset]
//        offset += 1
//        let leafVersion = keyVal.value[offset]
//        offset += 1
//    }
    while byteStream.offset < keyVal.value.count {
        let depth = byteStream.read(UInt8.self)
        let leafVersion = byteStream.read(UInt8.self)
        let script = byteStream.read(Data.self)
        data.append(
            .init(leafVersion: leafVersion, script: script, depth: depth)
        )
    }

    return .init(leaves: data)
}
