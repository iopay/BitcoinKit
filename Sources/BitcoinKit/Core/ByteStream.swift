//
//  ByteStream.swift
//
//  Copyright © 2018 Kishikawa Katsumi
//  Copyright © 2018 BitcoinKit developers
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

class ByteStream {
    let data: Data
    private(set) var offset = 0

    var availableBytes: Int {
        return data.count - offset
    }

    init(_ data: Data) {
        self.data = data
        self.offset = data.startIndex
    }

    func read<T: FixedWidthInteger>(_ type: T.Type, bigEndian: Bool = false) -> T {
        let size = MemoryLayout<T>.size
        let value = data[offset..<(offset + size)].to(type: type)
        offset += size
        return bigEndian ? T(bigEndian: value) : value
    }

    func readBool() -> Bool {
        let value = data[offset..<(offset + 1)].to(type: Bool.self)
        offset += 1
        return value
    }

    func read(_ type: VarInt.Type) -> VarInt {
        let len = data[offset..<(offset + 1)].to(type: UInt8.self)
        let length: UInt64
        switch len {
        case 0...252:
            length = UInt64(len)
            offset += 1
        case 0xfd:
            offset += 1
            length = UInt64(data[offset..<(offset + 2)].to(type: UInt16.self))
            offset += 2
        case 0xfe:
            offset += 1
            length = UInt64(data[offset..<(offset + 4)].to(type: UInt32.self))
            offset += 4
        case 0xff:
            offset += 1
            length = UInt64(data[offset..<(offset + 8)].to(type: UInt64.self))
            offset += 8
        default:
            offset += 1
            length = UInt64(data[offset..<(offset + 8)].to(type: UInt64.self))
            offset += 8
        }
        return VarInt(length)
    }

    func read(_ type: VarString.Type) -> VarString {
        let length = read(VarInt.self).underlyingValue
        let size = Int(length)
        let value = data[offset..<(offset + size)].to(type: String.self)
        offset += size
        return VarString(value)
    }

    func read(_ type: Data.Type, count: Int) -> Data {
        let value = data[offset..<(offset + count)]
        offset += count
        return Data(value)
    }

    func read(_ type: Data.Type) -> Data {
        let len = read(VarInt.self)
        return read(Data.self, count: Int(len.underlyingValue))
    }

    func read(_ type: [Data].Type) -> [Data] {
        let len = read(VarInt.self)
        return (0..<len.underlyingValue).map { _ in
            read(Data.self)
        }
    }

    @discardableResult
    func advance(by n: Data.Index) -> Data.Index {
        offset = offset.advanced(by: n)
        return offset
    }
}
