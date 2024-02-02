//
//  Bech32m.swift
//
//
//  Created by liugang zhang on 2024/1/29.
//

import Foundation

public struct Bech32m {
    public static func encode(payload: Data, prefix: String, separator: String = "1") -> String {
        Bech32.encode(payload: payload, prefix: prefix, separator: separator, const: 0x2bc830a3)
    }
}
