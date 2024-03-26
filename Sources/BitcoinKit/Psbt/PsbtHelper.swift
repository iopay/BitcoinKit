//
//  PsbtHelper.swift
//
//
//  Created by liugang zhang on 2024/3/25.
//

import Foundation


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
