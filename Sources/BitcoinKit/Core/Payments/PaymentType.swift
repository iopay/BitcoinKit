import Foundation

public protocol PaymentType {
//    associatedtype input = PaymentInput
    var output: Data { get }
    init(output: Data) throws
}

//public protocol PaymentInput {
//    var input: Data { get }
////    var signature: Data { get }
//    var witness: [Data] { get }
//}
public protocol WitnessPaymentType: PaymentType {
    static func inputFromSignature(_ sig: [PartialSig]) -> Data
    static func witnessFromSignature(_ sig: [PartialSig]) -> [Data]
}

extension WitnessPaymentType {
    func inputFromSignature(_ sig: [PartialSig]) -> Data {
        Self.inputFromSignature(sig)
    }

    func witnessFromSignature(_ sig: [PartialSig]) -> [Data] {
        Self.witnessFromSignature(sig)
    }
}

public enum PaymentError: Error {
    case outputInvalid
    case addressInvalid
}

public func isPaymentFactory(_ type: PaymentType.Type) -> (Data) -> Bool {
    { script in
        do {
            _ = try type.init(output: script)
            return true
        } catch {
            return false
        }
    }
}

public let isP2PK = isPaymentFactory(P2pk.self)
public let isP2SHScript = isPaymentFactory(P2sh.self)
public let isP2WSHScript = isPaymentFactory(P2Wsh.self)
public let isP2WPKH = isPaymentFactory(P2wpkh.self)
public let isP2PKH = isPaymentFactory(P2pkh.self)
public let isP2MS = isPaymentFactory(P2MS.self)

protocol A {
    associatedtype B //= Data

    var b: B { get }
}


struct Cc: A {
    var b: Never
    
    typealias B = Never
}
