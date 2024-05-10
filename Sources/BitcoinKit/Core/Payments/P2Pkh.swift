import Foundation

/// p2pkh(legacy address)
public struct P2pkh: WitnessPaymentType, Address {
    public let output: Data
    public let hash: Data
    public let address: String
    public let network: Network
    public let type: AddressType = .P2PKH

    public init(output: Data) throws {
        try self.init(output: output, network: .mainnetBTC)
    }

    public init(output: Data, network: Network = .mainnetBTC) throws {
        self.output = output
        self.network = network
        let chunks = Script(data: output)?.scriptChunks
        guard output.count == 25,
              chunks?.count == 5,
              chunks?[0].opCode == .OP_DUP,
              chunks?[1].opCode == .OP_HASH160,
              chunks?[3].opCode == .OP_EQUALVERIFY,
              chunks?[4].opCode == .OP_CHECKSIG, 
                let hashChunk = chunks?[2] as? DataChunk else {
                throw PaymentError.outputInvalid
        }
        self.hash = hashChunk.pushedData
        self.address = Base58Check.encode([network.pubkeyhash] + hash)
    }

    public init(pubkey: Data, network: Network = .mainnetBTC) {
        let hash = Crypto.sha256ripemd160(pubkey)
        self.init(hash: hash, network: network)
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

    public func inputFromSignature(_ sig: [PartialSig]) -> Data {
        try! Script().appendData(sig[0].signature).appendData(sig[0].pubkey).data
    }

    public func witnessFromSignature(_ sig: [PartialSig]) -> [Data] {
        []
    }
}
