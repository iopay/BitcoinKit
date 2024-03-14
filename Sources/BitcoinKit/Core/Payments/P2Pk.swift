import Foundation

public struct P2pkPayment: PaymentType {
    public let data: Data
    public let output: Data

    public init(data: Data) {
        self.data = data
        self.output = try! Script().appendData(data).append(.OP_CHECKSIG).data
    }

    public init(output: Data) throws {
        self.output = output
        let script = Script(data: output)!
        guard script.scriptChunks.count == 2, script.chunk(at: 1).opCode == .OP_CHECKSIG else {
            throw PaymentError.outputInvalid
        }
        self.data = script.chunk(at: 0).chunkData
    }
}
