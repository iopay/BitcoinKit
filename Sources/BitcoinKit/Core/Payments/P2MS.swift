//
//  P2MS.swift
//
//
//  Created by liugang zhang on 2024/4/16.
//

import Foundation

public struct P2MS: PaymentType {
    public var output: Data
    
    public init(output: Data) throws {
        throw NSError(domain: "p2ms not implement", code: 0)
    }
}
