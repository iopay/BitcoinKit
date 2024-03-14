import Foundation

/// p2pkh(legacy address)
public struct P2pkh: PaymentType, AddressType {
    public let output: Data
    public let hash: Data
    public let address: String
    public let network: Network

    public init(output: Data, network: Network = .mainnetBTC) throws {
        self.output = output
        self.network = network
        let script = Script(data: output)!
        guard output.count == 25,
              script.scriptChunks.count == 5,
              script.chunk(at: 0).opCode == .OP_DUP,
              script.chunk(at: 1).opCode == .OP_HASH160,
              script.chunk(at: 3).opCode == .OP_EQUALVERIFY,
              script.chunk(at: 4).opCode == .OP_CHECKSIG else {
                throw PaymentError.outputInvalid
        }
        self.hash = script.chunk(at: 2).chunkData
        self.address = Base58Check.encode([network.pubkeyhash] + hash)
    }

    public init(pubkey: Data, network: Network = .mainnetBTC) {
        self.hash = Crypto.sha256ripemd160(pubkey)
        self.network = network
        self.address = Base58Check.encode([network.pubkeyhash] + hash)
        self.output = try! Script()
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(hash)
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
            .data
    }

    public init(hash: Data, network: Network = .mainnetBTC) {
        self.hash = hash
        self.network = network
        self.address = Base58Check.encode([network.pubkeyhash] + hash)
        self.output = try! Script()
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(hash)
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
            .data
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
        self.output = try! Script()
            .append(.OP_DUP)
            .append(.OP_HASH160)
            .appendData(hash)
            .append(.OP_EQUALVERIFY)
            .append(.OP_CHECKSIG)
            .data
    }
}
