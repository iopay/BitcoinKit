//
//  Address.swift
// 
//  Copyright © 2019 BitcoinKit developers
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
//  THE SOFTWARE.
//

import Foundation

public protocol Address: CustomStringConvertible {
    var network: Network { get }
    var hashType: BitcoinAddress.HashType { get }
    var data: Data { get }
    var legacy: String { get }
    var cashaddr: String { get }
}

extension Address {
    @available(*, deprecated, message: "Always returns nil. If you need public key with address, please use PublicKey instead.")
    public var publicKey: Data? {
        return nil
    }

    @available(*, deprecated, renamed: "legacy")
    public var base58: String {
        return legacy
    }

    @available(*, deprecated, renamed: "hashType")
    public var type: BitcoinAddress.HashType {
        return hashType
    }
}

public protocol PaymentType {
//    var data: Data { get }
    var output: Data { get }
}

public protocol AddressType {
    var address: String { get }
    var network: Network { get }
    var script: Data { get }
}

public extension AddressType where Self: PaymentType {
    var script: Data {
        output
    }
}

public enum PaymentError: Error {
    case outputInvalid
    case addressInvalid
}

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

public struct P2sh: PaymentType, AddressType {
    public let output: Data
    public let hash: Data
    public let address: String
    public let network: Network

    public init(redeem: PaymentType, network: Network = .mainnetBTC) {
//        self.output = output
        self.network = network
        self.hash = Crypto.ripemd160(redeem.output)
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

public struct P2wpkh: PaymentType, AddressType {
    public var output: Data
    public let hash: Data
    public var address: String
    public var network: Network

    public init(pubkey: Data, network: Network = .mainnetBTC) throws {
        self.network = network
        self.hash = Crypto.sha256ripemd160(pubkey)
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

public func createAddressFromString(_ address: String) throws -> AddressType {
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
    }
    throw PaymentError.addressInvalid
}
