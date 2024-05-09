import Foundation

public protocol PaymentType {
    var output: Data { get }
    init(output: Data) throws
}

public protocol WitnessPaymentType: PaymentType {
    func inputFromSignature(_ sig: [PartialSig]) -> Data
    func witnessFromSignature(_ sig: [PartialSig]) -> [Data]
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
public let isP2TR = isPaymentFactory(P2tr.self)
