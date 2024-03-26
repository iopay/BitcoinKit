//
//  PsbtError.swift
//  
//
//  Created by liugang zhang on 2024/3/26.
//

import Foundation

public enum PsbtError: Error {
    case unexpectedEnd
    case invalidMagicNumber
    case keyMustUnique(String)
    case multiUnsignedTx
    case multipleInputKey(PsbtInputTypes)
    case invalidInputFormat(PsbtInputTypes, Data)
    case multipleOutputKey(PsbtOutputTypes)
    case invalidOutputFormat(PsbtOutputTypes, Data)
//    case invalidKey(key: PsbtInputTypes, buffer: Data)
//    case partialSigFromat(Data)
}
