//
//  Transaction+Psbt.swift
//
//
//  Created by liugang zhang on 2024/3/26.
//

import Foundation

extension Transaction {
    public static func fromPsbtHex(_ hex: String) throws -> Transaction {
        try fromPsbtHex(Data(hex: hex))
    }

    public static func fromPsbtHex(_ buffer: Data) throws -> Transaction {
        let byteStream = ByteStream(buffer)

        guard byteStream.read(UInt32.self, bigEndian: true) == 0x70736274, byteStream.read(UInt8.self) == 0xff else {
            throw PsbtError.invalidMagicNumber
        }

        var globalKeyIndex = [String: Bool]()
        var globalMapKeyVals = [PsbtKeyValue]()
        while try byteStream.read(UInt8.self) != 0 {
            byteStream.advance(by: -1)

            let key = try byteStream.read(Data.self)
            let value = try byteStream.read(Data.self)
            if globalKeyIndex[key.hex] == true {
                throw PsbtError.keyMustUnique(key.hex)
            }
            globalKeyIndex[key.hex] = true
            globalMapKeyVals.append(PsbtKeyValue(key, value))
        }

        let unsignedTxMaps = globalMapKeyVals.filter { $0.key.bytes[0] == PsbtGlobalTypes.UNSIGNED_TX.rawValue }
        guard unsignedTxMaps.count == 1 else {
            throw PsbtError.multiUnsignedTx
        }

        var unsigned = Transaction.deserialize(unsignedTxMaps[0].value)
        unsigned.unsigned = unsignedTxMaps[0].value

        var inputKeyVals = [[PsbtKeyValue]]()
        var outputKeyVals = [[PsbtKeyValue]]()

        for _ in 0..<unsigned.inputs.count {
            var inputKeyIndex = [String: Bool]()
            var input = [PsbtKeyValue]()
            while try byteStream.read(UInt8.self) != 0 {
                byteStream.advance(by: -1)

                let key = try byteStream.read(Data.self)
                let value = try byteStream.read(Data.self)

                if inputKeyIndex[key.hex] == true {
                    throw PsbtError.keyMustUnique(key.hex)
                }
                inputKeyIndex[key.hex] = true
                input.append(PsbtKeyValue(key, value))
            }
            inputKeyVals.append(input)
        }

        for _ in 0..<unsigned.outputs.count {
            var outputKeyIndex = [String: Bool]()
            var output = [PsbtKeyValue]()
            while try byteStream.read(UInt8.self) != 0 {
                byteStream.advance(by: -1)

                let key = try byteStream.read(Data.self)
                let value = try byteStream.read(Data.self)

                if outputKeyIndex[key.hex] == true {
                    throw PsbtError.keyMustUnique(key.hex)
                }
                outputKeyIndex[key.hex] = true
                output.append(PsbtKeyValue(key, value))
            }
            outputKeyVals.append(output)
        }

        var txExist = false
        for keyVals in globalMapKeyVals {
            switch keyVals.key[0] {
            case PsbtGlobalTypes.UNSIGNED_TX.rawValue:
                guard !txExist else {
                    throw PsbtError.multiUnsignedTx
                }
                txExist = true
            case PsbtGlobalTypes.GLOBAL_XPUB.rawValue:
                if unsigned.globalXpub == nil {
                    unsigned.globalXpub = []
                }
                unsigned.globalXpub?.append(try decodeGlobalXpub(keyVal: keyVals))
            default:
                if unsigned.unknownKeyVals == nil {
                    unsigned.unknownKeyVals = []
                }
                unsigned.unknownKeyVals?.append(keyVals)
            }
        }

        for i in 0..<unsigned.inputs.count {
            unsigned.inputs[i].update = try PsbtInputUpdate.deserialize(from: inputKeyVals[i])
        }

        for i in 0..<unsigned.outputs.count {
            unsigned.outputs[i].update = try PsbtOutputUpdate.deserialize(from: outputKeyVals[i])
        }

        return unsigned
    }

    public func serializedKeyVals() -> [PsbtKeyValue] {
        var keyVals = [PsbtKeyValue]()
        if let unsigned {
            keyVals.append(PsbtKeyValue(Data([PsbtGlobalTypes.UNSIGNED_TX.rawValue]), unsigned))
        }
        if let globalXpub {
            keyVals.append(contentsOf: globalXpub.compactMap { $0.serializedKeyVal() })
        }
        return keyVals
    }

    public func serializedPsbtHex() -> Data {
        var data = Data()
        data += UInt32(0x70736274).bigEndian
        data += UInt8(0xff)
        data += serializedKeyVals().serialized()

        let inputKeyVals = inputs.map { $0.update.serializedKeyVals() }
        if inputKeyVals.isEmpty {
            data += UInt8(0x00)
        } else {
            inputKeyVals.forEach { data += $0.serialized() }
        }

        let outputKeyVals = outputs.map { $0.update.serializedKeyVals() }
        if outputKeyVals.isEmpty {
            data += UInt8(0x00)
        } else {
            outputKeyVals.forEach { data += $0.serialized() }
        }
        return data
    }
}
