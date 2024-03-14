import Foundation

/// p2sh-p2wpkh (nested segwit address)
public struct P2sh: PaymentType, AddressType {
    public let output: Data
    public let hash: Data
    public let address: String
    public let network: Network

    public init(redeem: PaymentType, network: Network = .mainnetBTC) {
        self.network = network
        self.hash = Crypto.sha256ripemd160(redeem.output)
        self.output = try! Script().append(.OP_HASH160).appendData(hash).append(.OP_EQUAL).data
        self.address = Base58Check.encode([network.scripthash] + hash)
    }

    public init(output: Data, network: Network = .mainnetBTC) throws {
        self.output = output
        self.network = network
        let script = Script(data: output)!
        guard output.count == 23,
              script.scriptChunks.count == 3,
              script.chunk(at: 0).opCode == .OP_HASH160,
              script.chunk(at: 2).opCode == .OP_EQUAL else {
                throw PaymentError.outputInvalid
        }
        self.hash = script.chunk(at: 1).chunkData
        self.address = Base58Check.encode([network.scripthash] + hash)
    }

    public init(hash: Data, network: Network = .mainnetBTC) {
        self.hash = hash
        self.network = network
        self.address = Base58Check.encode([network.scripthash] + hash)
        self.output = try! Script().append(.OP_HASH160).appendData(hash).append(.OP_EQUAL).data
    }

    public init(address: String) throws {
        guard let decoded = Base58Check.decode(address), decoded.count == 21 else {
            throw PaymentError.addressInvalid
        }
        let version = decoded[0]
        switch version {
        case Network.mainnetBTC.scripthash:
            self.network = .mainnetBTC
        case Network.testnetBTC.scripthash:
            self.network = .testnetBTC
        default:
            throw PaymentError.addressInvalid
        }
        self.address = address
        self.hash = Data(decoded[1...])
        self.output = try! Script().append(.OP_HASH160).appendData(hash).append(.OP_EQUAL).data
    }
}
