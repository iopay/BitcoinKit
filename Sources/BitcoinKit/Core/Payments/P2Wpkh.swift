import Foundation

/// p2wpkh(native segwit address)
public struct P2wpkh: PaymentType, Address {
    public var output: Data
    public let hash: Data
    public var address: String
    public var network: Network
    public let type: AddressType = .P2WPKH

    public init(pubkey: Data, network: Network = .mainnetBTC) {
        self.network = network
        self.hash = Crypto.sha256ripemd160(pubkey)
        self.output = try! Script().append(.OP_0).appendData(hash).data

        let words: Data = [0x00] + Bech32.convertTo5bit(data: hash, pad: true)
        self.address = Bech32.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }

    public init(hash: Data, network: Network = .mainnetBTC) {
        self.network = network
        self.hash = hash
        self.output = try! Script().append(.OP_0).appendData(hash).data

        let words: Data = [0x00] + Bech32.convertTo5bit(data: hash, pad: true)
        self.address = Bech32.encode(payload: words, prefix: network.bech32Prefix, separator: "1")
    }

    public init(address: String) throws {
        guard let (prefix, data) = Bech32.decode(address, separator: "1") else {
            throw PaymentError.addressInvalid
        }
        self.hash = data
        switch prefix {
        case Network.mainnetBTC.bech32Prefix:
            self.network = .mainnetBTC
        case Network.testnetBTC.bech32Prefix:
            self.network = .testnetBTC
        default:
            throw PaymentError.addressInvalid
        }
        self.address = address
        self.output = try! Script().append(.OP_0).appendData(hash).data
    }
}
