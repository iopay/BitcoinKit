import Foundation

/// p2tr (taproot address)
public struct P2tr: PaymentType, Address {
    public var output: Data
    public var address: String
    public var network: Network
    public let type: AddressType = .P2TR

    public init(pubKey: Data, network: Network = .mainnetBTC) {
//        self.hash = hash
        self.network = network
        self.output = try! Script().append(.OP_1).appendData(pubKey).data
        let words: Data = [0x01] + Bech32.convertTo5bit(data: pubKey.xOnly, pad: true)
        self.address = Bech32m.encode(payload: words, prefix: network.bech32Prefix)
    }

    public init(internalPubKey: Data, network: Network = .mainnetBTC) {
        let pub = tweakKey(pubKey: internalPubKey, h: nil)
        self.init(pubKey: pub!, network: network)
    }

    public init(output: Data) throws {
        self.init(output: output, network: .mainnetBTC)
    }
    
    public init(output: Data, network: Network = .mainnetBTC) {
        let pubkey = output[2...]
        self.init(pubKey: pubkey, network: network)
    }

    public init(address: String) throws {
        guard let (prefix, data) = Bech32m.decode(address: address) else {
            throw PaymentError.addressInvalid
        }
        guard data[0] != 0, let payload = try? Bech32.convertFrom5bit(data: data[1...]) else {
            throw PaymentError.addressInvalid
        }
        switch prefix {
        case Network.mainnetBTC.bech32Prefix:
            self.network = .mainnetBTC
        case Network.testnetBTC.bech32Prefix:
            self.network = .testnetBTC
        default:
            throw PaymentError.addressInvalid
        }
        self.address = address
        self.output = try! Script().append(.OP_1).appendData(payload).data
    }
}
