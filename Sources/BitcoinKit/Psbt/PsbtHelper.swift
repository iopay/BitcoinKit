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
