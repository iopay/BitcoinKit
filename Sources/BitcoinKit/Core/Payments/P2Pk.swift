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
        let script = Script(data: output)!
        guard script.scriptChunks.count == 2, script.chunk(at: 1).opCode == .OP_CHECKSIG else {
            throw PaymentError.outputInvalid
        }
        self.pubKey = script.chunk(at: 0).chunkData
    }

    public func inputFromSignature(_ sig: [PartialSig]) -> Data {
        try! Script().appendData(sig[0].signature).data
    }

    public func witnessFromSignature(_ sig: [PartialSig]) -> [Data] {
        []
    }
}
