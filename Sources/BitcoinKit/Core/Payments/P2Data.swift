import Foundation

public struct P2Data: PaymentType {
    public let data: Data
    public let output: Data

    public init(data: Data) {
        self.data = data
        self.output = try! Script().append(.OP_RETURN).appendData(data).data
    }

    public init(output: Data) throws {
        self.output = output
        let script = Script(data: output)!
        guard script.scriptChunks.count == 2, script.chunk(at: 0).opCode == .OP_RETURN else {
            throw PaymentError.outputInvalid
        }
        self.data = script.chunk(at: 1).chunkData
    }
}
