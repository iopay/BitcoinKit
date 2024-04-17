import Foundation

public indirect enum AddressType: Equatable {
    case P2PKH
    case P2WPKH
    case P2SH(AddressType?)
    case P2WSH(AddressType?)
    case P2TR
}

public protocol Address {
    var address: String { get }
    var network: Network { get }
    var script: Data { get }
    var type: AddressType { get }

    init(address: String) throws
}

public extension Address where Self: PaymentType {
    var script: Data {
        output
    }
}

public func createAddressFromString(_ address: String) throws -> Address {
    if let base58 = Base58Check.decode(address) {
        guard base58.count == 21 else {
            throw PaymentError.addressInvalid
        }
        if base58[0] == Network.mainnetBTC.pubkeyhash || base58[0] == Network.testnetBTC.pubkeyhash {
            let network = if base58[0] == Network.mainnetBTC.pubkeyhash {
                Network.mainnetBTC
            } else {
                Network.testnetBTC
            }
            return P2pkh(hash: base58[1...], network: network)
        }
        if base58[0] == Network.mainnetBTC.scripthash || base58[0] == Network.testnetBTC.scripthash {
            let network = if base58[0] == Network.mainnetBTC.scripthash {
                Network.mainnetBTC
            } else {
                Network.testnetBTC
            }
            return P2sh(hash: base58[1...], network: network)
        }
    } else if let (prefix, version, data) = fromBech32(address) {
        guard prefix == Network.mainnetBTC.bech32Prefix || prefix == Network.testnetBTC.bech32Prefix else {
            throw PaymentError.addressInvalid
        }
        let network = if prefix == Network.mainnetBTC.bech32Prefix {
            Network.mainnetBTC
        } else {
            Network.testnetBTC
        }
        if version == 0 {
            if data.count == 20 {
                return P2wpkh(hash: data, network: network)
            } else if data.count == 32 {
                return P2Wsh(hash: data, network: network)
            }
        } else if version == 1 {
            if data.count == 32 {
                return P2tr(pubKey: data, network: network)
            }
        }
    }
    throw PaymentError.addressInvalid
}

public func fromBech32(_ address: String) -> (prefix: String, version: UInt8, data: Data)? {
    if let (prefix, data) = Bech32.decode(address) {
        guard data[0] == 0, let payload = try? Bech32.convertFrom5bit(data: data[1...]) else {
            return nil
        }
        return (prefix, data[0], payload)
    } else if let (prefix, data) = Bech32m.decode(address: address) {
        guard data[0] != 0, let payload = try? Bech32.convertFrom5bit(data: data[1...]) else {
            return nil
        }
        return (prefix, data[0], payload)
    }
    return nil
}
