import Foundation

//public func isP2WPKH(_ data: Data) -> Bool {
//    data.count == 22 &&
//    data[0] == Op0().value &&
//    data[1] == 0x14
//}
//
//public func isP2PKH(_ data: Data) -> Bool {
//    data.count == 25 &&
//    data[0] == OpDuplicate().value &&
//    data[1] == OpHash160().value &&
//    data[2] == 0x14 &&
//    data[23] == OpEqualVerify().value &&
//    data[24] == OpCheckSig().value
//}

//public func isP2TR(_ data: Data) -> Bool {
//    data.count == 34 &&
//    data[0] == OpCode.OP_1.value &&
//    data[1] == 0x20
//}

public func toXOnly(_ data: Data) -> Data {
    data.count == 32 ? data : data.dropFirst()
}
