//
//  PsbtError.swift
//  
//
//  Created by liugang zhang on 2024/3/26.
//

import Foundation

public enum PsbtError: Error {
    case indexOutOfBounds
    case utxoInputItemRequired
    case p2shMissingRedeemScript
    case p2wshMissingWitnessScript
    case unexpectedEnd
    case invalidMagicNumber
    case keyMustUnique(String)
    case multiUnsignedTx
    case multipleInputKey(PsbtInputTypes)
    case invalidInputFormat(PsbtInputTypes, Data)
    case multipleOutputKey(PsbtOutputTypes)
    case invalidOutputFormat(PsbtOutputTypes, Data)
    case sigHashTypeMissMatch
}
