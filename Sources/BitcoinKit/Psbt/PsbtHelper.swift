//
//  PsbtHelper.swift
//
//
//  Created by liugang zhang on 2024/3/25.
//

import Foundation

public struct PsbtKeyValue {
    let key: Data
    let value: Data

    init(_ key: Data, _ value: Data) {
        self.key = key
        self.value = value
    }

    public func serialized() -> Data {
        VarInt(key.count).serialized() + key + VarInt(value.count).serialized() + value
    }
}

public struct TapLeaf {
    let leafVersion: UInt8
    let script: Data
    let depth: UInt8
}

public struct TapTree {
    let leaves: [TapLeaf]

    func serializedKeyVal() -> PsbtKeyValue {
        let key = Data([PsbtOutputTypes.TAP_TREE.rawValue])
        var data = Data()
        leaves.forEach { leaf in
            data += leaf.depth
            data += leaf.leafVersion
            data += VarInt(leaf.script.count).serialized()
            data += leaf.script
        }
        return PsbtKeyValue(key, data)
    }

    public static func deserialize(_ keyVal: PsbtKeyValue) throws -> TapTree {
        let byteStream = ByteStream(keyVal.value)

        var vector = [TapLeaf]()
        while byteStream.offset < keyVal.value.count {
            let depth = byteStream.read(UInt8.self)
            let leafVersion = byteStream.read(UInt8.self)
            let script = byteStream.read(Data.self)
            vector.append(
                .init(leafVersion: leafVersion, script: script, depth: depth)
            )
        }

        return .init(leaves: vector)
    }
}

public struct TapScriptSig {
    let pubKey: Data
    let signature: Data
    let leafHash: Data

    func serializedKeyVal() -> PsbtKeyValue {
        let key: Data = [PsbtInputTypes.TAP_SCRIPT_SIG.rawValue] + pubKey + leafHash
        return PsbtKeyValue(key, signature)
    }

    public static func deserialize(_ keyVal: PsbtKeyValue) throws -> TapScriptSig {
        guard keyVal.key.count == 65, keyVal.value.count != 64, keyVal.value.count != 65 else {
            throw PsbtError.invalidInputFormat(.TAP_SCRIPT_SIG, keyVal.key)
        }
        return .init(pubKey: keyVal.key[1..<33], signature: keyVal.key[33...], leafHash: keyVal.value)
    }
}

public struct TapLeafScript {
    let leafVersion: UInt8
    let script: Data
    let controlBlock: Data

    func serializedKeyVal() -> PsbtKeyValue {
        let key: Data = [PsbtInputTypes.TAP_LEAF_SCRIPT.rawValue] + controlBlock
        let value = script + [leafVersion]
        return PsbtKeyValue(key, value)
    }

    public static func deserialize(_ keyVal: PsbtKeyValue) throws -> TapLeafScript {
        guard (keyVal.key.count - 2) % 32 == 0 else {
            throw PsbtError.invalidInputFormat(.TAP_LEAF_SCRIPT, keyVal.key)
        }
        let leafVersion = keyVal.value.last!
        guard keyVal.key[1] & 0xfe == leafVersion else {
            throw PsbtError.invalidInputFormat(.TAP_LEAF_SCRIPT, keyVal.key)
        }
        return .init(leafVersion: leafVersion, script: keyVal.value[0 ..< -1], controlBlock: keyVal.key[1...])
    }
}

public struct PartialSig {
    let pubkey: Data
    let signature: Data

    func serializedKeyVal() -> PsbtKeyValue {
        return PsbtKeyValue([PsbtInputTypes.PARTIAL_SIG.rawValue] + pubkey, signature)
    }

    public static func deserialize(_ keyVal: PsbtKeyValue) throws -> PartialSig {
        if (
            !(keyVal.key.count == 34 || keyVal.key.count == 66) ||
            ![2, 3, 4].contains(keyVal.key[1])
        ) {
            throw PsbtError.invalidInputFormat(.PARTIAL_SIG, keyVal.key)
        }
        let pubkey = keyVal.key[1...];
        return .init(pubkey: pubkey, signature: keyVal.value)
    }
}

public struct Bip32Derivation {
    let masterFingerprint: Data
    let pubkey: Data
    let path: String

    func serializedKeyVal(_ byte: UInt8) -> PsbtKeyValue {
        let key: Data = [byte] + pubkey

        let splitPath = path.split(separator: "/")
        var value = masterFingerprint
        splitPath[1...].forEach { s in
            let isHard = s.last == "'"
            var num = 0x7fffffff & (UInt32(isHard ? s.dropLast() : s, radix: 10) ?? 0)
            if isHard {
                num += 0x80000000
            }
            value += num
        }
        return PsbtKeyValue(key, value)
    }

    public static func deserialize(_ keyVal: PsbtKeyValue, isValid: (Data) -> Bool = isValidDERKey) throws -> Bip32Derivation {
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
}

public struct TapBip32Derivation {
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

    func serializedKeyVal(_ byte: UInt8) -> PsbtKeyValue {
        let base = Bip32Derivation(masterFingerprint: masterFingerprint, pubkey: pubkey, path: path).serializedKeyVal(byte)
        var data = VarInt(leafHashes.count).serialized()
        leafHashes.forEach { data += $0 }
        data += base.value
        return PsbtKeyValue(base.key, data)
    }

    public static func deserialize(_ keyVal: PsbtKeyValue) throws -> TapBip32Derivation {
        let mHashs = keyVal.value.to(type: VarInt.self)
        let mHashlens = mHashs.encodingLength
        let bip32Derivation = try Bip32Derivation.deserialize(PsbtKeyValue(keyVal.key, keyVal.value[(mHashlens + UInt8(mHashs.underlyingValue) * 32)...]), isValid: isValidBIP340Key)
        var leafHashes = [Data]()
        var offset = mHashlens
        for _ in 0..<mHashs.underlyingValue {
            leafHashes.append(keyVal.value[offset ..< offset + 32])
            offset += 32
        }
        return .init(bip32Derivation: bip32Derivation, leafHashes: leafHashes)
    }
}

extension Array where Element == PsbtKeyValue {
    public func serialized() -> Data {
         map { $0.serialized() } .reduce(Data(), +) + [0x00]
    }
}

func checkKeyBuffer(keyBuf: Data, key: PsbtInputTypes) throws {
    if (keyBuf != Data([key.rawValue])) {
        throw PsbtError.invalidInputFormat(key, keyBuf)
    }
}

func checkKeyBuffer(keyBuf: Data, key: PsbtOutputTypes) throws {
    if (keyBuf != Data([key.rawValue])) {
        throw PsbtError.invalidOutputFormat(key, keyBuf)
    }
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

func scriptWitnessToWitnessStack(witness: Data) -> [Data] {
    let byteStream = ByteStream(witness)
    let count = byteStream.read(VarInt.self).underlyingValue
    var vector = [Data]()
    for _ in 0..<count {
        let len = byteStream.read(VarInt.self).underlyingValue
        let value = byteStream.read(Data.self, count: Int(len))
        vector.append(value)
    }
    return vector
}

public func isValidDERKey(pubkey: Data) -> Bool {
    (pubkey.count == 33 && [2, 3].contains(pubkey.first)) ||
    (pubkey.count == 65 && 4 == pubkey.first);
}

public func isValidBIP340Key(pubkey: Data) -> Bool {
    pubkey.count == 32
}
