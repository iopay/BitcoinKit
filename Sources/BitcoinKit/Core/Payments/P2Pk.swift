import Foundation

public struct P2pk: WitnessPaymentType {
    public let pubKey: Data
    public let output: Data

    public init(pubKey: Data) {
        self.pubKey = pubKey
        self.output = try! Script().appendData(pubKey).append(.OP_CHECKSIG).data
    }

    public init(output: Data) throws {
        self.output = output
        let chunks = Script(data: output)?.scriptChunks
        guard chunks?.count == 2, chunks?[1].opCode == .OP_CHECKSIG, let pk = chunks?[0] as? DataChunk else {
            throw PaymentError.outputInvalid
        }
        self.pubKey = pk.pushedData
    }

    public func inputFromSignature(_ sig: [PartialSig]) -> Data {
        try! Script().appendData(sig[0].signature).data
    }

    public func witnessFromSignature(_ sig: [PartialSig]) -> [Data] {
        []
    }
}
