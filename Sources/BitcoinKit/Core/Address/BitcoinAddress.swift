//
//  BitcoinAddress.swift
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

/// BitcoinAddress will be renamed to `Address` in ver.2.0.0. The model to represent Bitcoin address.
///
/// ```
/// // Initialize from legacy address (Base58Check format) string
/// let legacy = try BitcoinAddress(legacy: "1AC4gh14wwZPULVPCdxUkgqbtPvC92PQPN")
///
/// // Initialize from cash address (Cashaddr format) string
/// let cashaddr = try BitcoinAddress(cashaddr: "bitcoincash:qpjdpjrm5zvp2al5u4uzmp36t9m0ll7gd525rss978")
///
/// // Initialize from data
/// let p2pkhAddress = try BitcoinAddress(data: pubkeyHash, type: .pubkeyHash, network: .mainnetBCH)
/// let p2shAddress = try BitcoinAddress(data: scriptHash, type: .scriptHash, network: .mainnetBCH)
/// ```
public struct BitcoinAddress {
    public let data: Data
    public let network: Network

    // Bitcoin Address parameter
    public let hashType: HashType
    public let hashSize: HashSize

    /// Creates a new BitcoinAddress instance with raw parameters.
    ///
    /// This initializer performs hash size validation.
    /// ```
    /// // Initialize address from raw parameters
    /// let address = try BitcoinAddress(data: pubkeyHash,
    ///                            type: .pubkeyHash,
    ///                            network: .mainnetBCH)
    /// ```
    ///
    /// - Parameters:
    ///   - data: The hash of public key or script
    ///   - hashType: .pubkeyHash or .scriptHash
    ///   - network: BitcoinCash network .mainnetBCH or .testnetBCH is expected. But you can
    ///     also use other network.
    public init(data: Data, hashType: HashType, network: Network) throws {
        guard let hashSize = HashSize(sizeInBits: data.count * 8) else {
            throw AddressError.invalidDataSize
        }

        self.data = data
        self.hashType = hashType
        self.hashSize = hashSize

        self.network = network
    }
}

extension BitcoinAddress: CustomStringConvertible {
    public var description: String {
        switch network {
        case .mainnetBCH, .testnetBCH:
            return cashaddr
        default:
            return legacy
        }
    }
}

extension BitcoinAddress: Equatable {
    public static func == (lhs: BitcoinAddress, rhs: BitcoinAddress) -> Bool {
        return lhs.data == rhs.data
            && lhs.hashType == rhs.hashType
            && lhs.hashSize == rhs.hashSize
    }
}

#if os(iOS) || os(tvOS) || os(watchOS)
extension BitcoinAddress: QRCodeConvertible {}
#endif

extension BitcoinAddress {
    public var bech32Prefix: String {
        switch network {
        case .mainnetBCH, .mainnetBTC:
            return "bc"
        default:
            return "tb"
        }
    }

    public var bech32: String {
        let words: Data = [0x00] + Bech32.convertTo5bit(data: data, pad: true)
        let prefix = bech32Prefix
        let checksumUint5: Data = Bech32.createChecksum(prefix: prefix, payload: words) // Data of [UInt5]
        let combined: Data = words + checksumUint5 // Data of [UInt5]
        var base32 = "1"
        for b in combined {
            let index = String.Index(utf16Offset: Int(b), in: Bech32.base32Alphabets)
            base32 += String(Bech32.base32Alphabets[index])
        }

        return prefix + base32
    }

    public init(bech32: String) throws {
        guard let (prefix, hash) = Bech32.decode(bech32, separator: "1") else {
            throw AddressError.invalid
        }
        guard let hashSize = HashSize(sizeInBits: hash.count * 8) else {
            throw AddressError.invalidDataSize
        }
        self.data = hash
        self.hashSize = hashSize
        self.hashType = .scriptHash

        switch prefix {
        case "bc":
            network = .mainnetBTC
        case "tb":
            network = .testnetBTC
        default:
            throw AddressError.invalidVersionByte
        }
    }
}
