//
//  OP_NOP.swift
//  BitcoinCashKit
//
//  Created by Shun Usami on 2018/08/08.
//  Copyright © 2018 BitcoinCashKit developers. All rights reserved.
//

import Foundation

public struct OpNop: OpCodeProtocol {
    public var value: UInt8 { return 0x61 }
    public var name: String { return "OP_NOP" }
    
    public func mainProcess(_ context: ScriptExecutionContext) throws {
    }
}
