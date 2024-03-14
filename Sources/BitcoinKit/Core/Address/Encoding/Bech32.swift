//
//  Bech32.swift
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

/// A set of Bech32 coding methods.
///
/// ```
/// // Encode bytes to address
/// let cashaddr: String = Bech32.encode(payload: [versionByte] + pubkeyHash,
///                                      prefix: "bitcoincash")
///
/// // Decode address to bytes
/// guard let payload: Data = Bech32.decode(text: address) else {
///     // Invalid checksum or Bech32 coding
///     throw SomeError()
/// }
/// let versionByte = payload[0]
/// let pubkeyHash = payload.dropFirst()
/// ```
public struct Bech32 {
    internal static let base32Alphabets = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    /// Encodes the data to Bech32 encoded string
    ///
    /// Creates checksum bytes from the prefix and the payload, and then puts the
    /// checksum bytes to the original data. Then, encode the combined data to
    /// Base32 string. At last, returns the combined string of prefix, separator
    /// and the encoded base32 text.
    /// ```
    /// let address = Base58Check.encode(payload: [versionByte] + pubkeyHash,
    ///                                  prefix: "bitcoincash")
    /// ```
    /// - Parameters:
    ///   - payload: The data to encode
    ///   - prefix: The prefix of the encoded text. It is also used to create checksum.
    ///   - separator: separator that separates prefix and Base32 encoded text
//    public static func encode(payload: Data, prefix: String, separator: String = ":") -> String {
//        let payloadUint5 = convertTo5bit(data: payload, pad: true)
//        let checksumUint5: Data = createChecksum(prefix: prefix, payload: payloadUint5) // Data of [UInt5]
//        let combined: Data = payloadUint5 + checksumUint5 // Data of [UInt5]
//        var base32 = ""
//        for b in combined {
//            let index = String.Index(utf16Offset: Int(b), in: base32Alphabets)
//            base32 += String(base32Alphabets[index])
//        }
//
//        var chk = expand(prefix)
//        return prefix + separator + base32
//    }

    public static func encode(payload: Data, prefix: String, separator: String = "1", const: UInt32 = 1) -> String {
        var chk = prefixChk(prefix)
        var result = prefix + separator
        for x in payload {
            if x >> 5 != 0 {
                fatalError("Non 5-bit word")
            }
            chk = polymodStep(chk) ^ UInt32(x)
            let index = String.Index(utf16Offset: Int(x), in: base32Alphabets)
            result += String(base32Alphabets[index])
        }
        for _ in 0..<6 {
            chk = polymodStep(chk)
        }
        chk ^= const
        for i in 0..<6 {
            let v = (chk >> ((5 - i) * 5)) & 0x1f
            let index = String.Index(utf16Offset: Int(v), in: base32Alphabets)
            result += String(base32Alphabets[index])
        }
        return result
    }

    public static func decode(_ string: String, separator: String = "1", const: UInt32 = 1) -> (prefix: String, data: Data)? {
        guard !string.isEmpty, string == string.lowercased() || string == string.uppercased() else {
            return nil
        }
        let components = string.components(separatedBy: separator)
        guard components.count == 2 else {
            return nil
        }
        let (prefix, base32) = (components[0], components[1].lowercased())
        var chk = prefixChk(prefix)
        var words: [UInt8] = []
        for (i, c) in base32.enumerated() {
            guard let baseIndex = base32Alphabets.firstIndex(of: c)?.utf16Offset(in: base32Alphabets) else {
                return nil
            }
            chk = polymodStep(chk) ^ UInt32(baseIndex)
            if i + 6 >= base32.count {
                continue
            }
            words.append(UInt8(baseIndex))
        }
        guard chk == const else {
            return nil
        }
        return (prefix, Data(words))
    }
    /// Decodes the Bech32 encoded string to original payload
    ///
    /// ```
    /// // Decode address to bytes
    /// guard let payload: Data = Bech32.decode(text: address) else {
    ///     // Invalid checksum or Bech32 coding
    ///     throw SomeError()
    /// }
    /// let versionByte = payload[0]
    /// let pubkeyHash = payload.dropFirst()
    /// ```
    /// - Parameters:
    ///   - string: The data to encode
    ///   - separator: separator that separates prefix and Base32 encoded text
//    public static func decode(_ string: String, separator: String = ":") -> (prefix: String, data: Data)? {
//        // We can't have empty string.
//        // Bech32 should be uppercase only / lowercase only.
//        guard !string.isEmpty && [string.lowercased(), string.uppercased()].contains(string) else {
//            return nil
//        }
//
//        let components = string.components(separatedBy: separator)
//        // We can only handle string contains both scheme and base32
//        guard components.count == 2 else {
//            return nil
//        }
//        let (prefix, base32) = (components[0], components[1])
//
//        var decodedIn5bit: [UInt8] = [UInt8]()
//        for c in base32.lowercased() {
//            // We can't have characters other than base32 alphabets.
//            guard let baseIndex = base32Alphabets.firstIndex(of: c)?.utf16Offset(in: base32Alphabets) else {
//                return nil
//            }
//            decodedIn5bit.append(UInt8(baseIndex))
//        }
//
//        // We can't have invalid checksum
//        let payload = Data(decodedIn5bit)
//        guard verifyChecksum(prefix: prefix, payload: payload) else {
//            return nil
//        }
//
//        // Drop checksum
//        guard let bytes = try? convertFrom5bit(data: payload.dropLast(6).dropFirst()) else {
//            return nil
//        }
//        return (prefix, Data(bytes))
//    }

    internal static func verifyChecksum(prefix: String, payload: Data) -> Bool {
        return polymod(expand(prefix) + payload) == 1
    }

    internal static func expand(_ hrp: String) -> Data {
        guard let hrpBytes = hrp.data(using: .utf8) else { return Data() }
        var result = Data(repeating: 0x00, count: hrpBytes.count*2+1)
        for (i, c) in hrpBytes.enumerated() {
            result[i] = c >> 5
            result[i + hrpBytes.count + 1] = c & 0x1f
        }
        result[hrp.count] = 0
        return result
    }

    internal static func createChecksum(prefix: String, payload: Data) -> Data {
        let enc: Data = expand(prefix) + payload + Data(repeating: 0x00, count: 6)
        let mod: UInt32 = polymod(enc) ^ 1
        var ret: Data = Data()
        for i in 0..<6 {
            ret += UInt8((mod >> (5 * (5 - i))) & 0x1f)
        }
        return ret
    }

    static func prefixChk(_ prefix: String) -> UInt32 {
        var chk: UInt32 = 1
        for c in prefix.utf8 {
            guard c >= 33 && c <= 126 else {
                fatalError("Invalid prefix: \(prefix)")
            }
            chk = polymodStep(chk) ^ (UInt32(c) >> 5)
        }
        chk = polymodStep(chk)
        for v in prefix.utf8 {
            chk = polymodStep(chk) ^ (UInt32(v) & 0x1f)
        }
        return chk
    }

    private static let gen: [UInt32] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    private static func polymod(_ values: Data) -> UInt32 {
        var chk: UInt32 = 1
        for v in values {
            let top = (chk >> 25)
            chk = (chk & 0x1ffffff) << 5 ^ UInt32(v)
            for i: UInt8 in 0..<5 {
                chk ^= ((top >> i) & 1) == 0 ? 0 : gen[Int(i)]
            }
        }
        return chk
    }

    static func polymodStep(_ pre: UInt32) -> UInt32 {
        let b = pre >> 25;
        var chk = (pre & 0x1ffffff) << 5
        for i: UInt8 in 0..<5 {
            chk ^= ((b >> i) & 1) == 0 ? 0 : gen[Int(i)]
        }
        return chk
    }

    internal static func PolyMod(_ data: Data) -> UInt64 {
        var c: UInt64 = 1
        for d in data {
            let c0: UInt8 = UInt8(c >> 35)
            c = ((c & 0x07ffffffff) << 5) ^ UInt64(d)
            if c0 & 0x01 != 0 { c ^= 0x98f2bc8e61 }
            if c0 & 0x02 != 0 { c ^= 0x79b76d99e2 }
            if c0 & 0x04 != 0 { c ^= 0xf33e5fb3c4 }
            if c0 & 0x08 != 0 { c ^= 0xae2eabe2a8 }
            if c0 & 0x10 != 0 { c ^= 0x1e4f43e470 }
        }
        return c ^ 1
    }

    internal static func convertTo5bit(data: Data, pad: Bool) -> Data {
        var acc = Int()
        var bits = UInt8()
        let maxv: Int = 31 // 31 = 0x1f = 00011111
        var converted: [UInt8] = []
        for d in data {
            acc = (acc << 8) | Int(d)
            bits += 8

            while bits >= 5 {
                bits -= 5
                converted.append(UInt8(acc >> Int(bits) & maxv))
            }
        }

        let lastBits: UInt8 = UInt8(acc << (5 - bits) & maxv)
        if pad && bits > 0 {
            converted.append(lastBits)
        }
        return Data(converted)
    }

    internal static func convertFrom5bit(data: Data) throws -> Data {
        var acc = Int()
        var bits = UInt8()
        let maxv: Int = 255 // 255 = 0xff = 11111111
        let maxAcc: Int = (1 << (5 + 8 - 1)) - 1
        var converted: [UInt8] = []
        for d in data {
            guard (d >> 5) == 0 else {
                throw DecodeError.invalidCharacter
            }
            acc = ((acc << 5) | Int(d)) & maxAcc
            bits += 5

            while bits >= 8 {
                bits -= 8
                converted.append(UInt8(acc >> Int(bits) & maxv))
            }
        }

        let lastBits: UInt8 = UInt8(acc << (8 - bits) & maxv)
        guard bits < 5 && lastBits == 0  else {
            throw DecodeError.invalidBits
        }

        return Data(converted)
    }

    internal enum DecodeError: Error {
        case invalidCharacter
        case invalidBits
    }
}
