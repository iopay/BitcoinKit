//
//  PsbtBuilderTests.swift
//
//
//  Created by liugang zhang on 2024/6/3.
//

import XCTest
@testable import BitcoinKit

var dummyUtxoIndex: UInt32 = 0

struct UTXO: UtxoType {
    var tx: Data
    
    var index: UInt32
    
    var amount: UInt64
    
    var addressType: BitcoinKit.AddressType
    
    var script: Data
    
    var pubKey: Data

    static func gen(pk: PrivateKey, addressType: AddressType, satoshis: UInt64) -> Self {
        defer { dummyUtxoIndex += 1 }

        return .init(tx: Data(repeating: 0x00, count: 32), index: dummyUtxoIndex, amount: satoshis, addressType: addressType, script: pk.toAddress(type: addressType).script, pubKey: pk.publicKey().data)
    }
}

class PsbtBuilderTests: XCTestCase {
    var from: PrivateKey!
    var to: PrivateKey!
    let addressTypes: [AddressType] = [
        .P2PKH,
        .P2WPKH,
        .P2TR,
        .P2SH(.P2WPKH)
    ]

    override func setUp() {
        from = PrivateKey()
        to = PrivateKey()
    }

    func expectFeeRate(type: AddressType, rate1: Double, rate2: Double) {
        let r = (rate1 * 10.0).rounded() / 10.0
        if type == .P2PKH || type == .P2WPKH {
            XCTAssertLessThanOrEqual(r, rate2 * 1.01)
            XCTAssertGreaterThanOrEqual(r, rate2 * 0.99)
        } else {
            XCTAssertEqual(r, rate2, "\(type)")
        }
    }

    func testBuild() throws {
        let feeRates: [Double] = [1, 1.3, 10, 1000, 10000]
        try addressTypes.forEach { type in
            try feeRates.forEach { feeRate in
                let (psbt, toSignInputs) = try PsbtBuilder.build(
                    [UTXO.gen(pk: from, addressType: type, satoshis: 100_000_000)],
                    to: [to.toAddress(type: type)],
                    toAmount: [1_000],
                    change: from.toAddress(type: type),
                    feeRate: feeRate
                )
                try from.sign(psbt, options: toSignInputs)

                let fee = psbt.fee
                let tx = psbt.extractTransaction()
                let virtualSize = tx.virtualSize
                let finalFeeRate = Double(fee) / Double(virtualSize)

                XCTAssertEqual(psbt.inputs.count, 1)
                XCTAssertEqual(psbt.outputs.count, 2)
                XCTAssertEqual(psbt.tx.outputs[0].value, 1000)
                expectFeeRate(type: type, rate1: finalFeeRate, rate2: feeRate)
            }
        }
    }

    func testBuildAll() throws {
        let feeRates: [Double] = [1, 1.3, 10, 1000, 10000]
        try addressTypes.forEach { type in
            try feeRates.forEach { feeRate in
                let (psbt, toSignInputs) = try PsbtBuilder.buildAll(
                    [
                        UTXO.gen(pk: from, addressType: type, satoshis: 100_000_000),
                        UTXO.gen(pk: from, addressType: type, satoshis: 100_000_000)
                    ],
                    to: to.toAddress(type: type),
                    feeRate: feeRate
                )

                try from.sign(psbt, options: toSignInputs)

                let fee = psbt.fee
                let tx = psbt.extractTransaction()
                let virtualSize = tx.virtualSize
                let finalFeeRate = Double(fee) / Double(virtualSize)

                XCTAssertEqual(psbt.inputs.count, 2)
                XCTAssertEqual(psbt.outputs.count, 1)
                XCTAssertEqual(tx.outputs[0].lockingScript, to.toAddress(type: type).script)
                expectFeeRate(type: type, rate1: finalFeeRate, rate2: feeRate)
            }
        }
    }

    func testBuild_1_of_2() throws {
        try addressTypes.forEach { type in
            let (psbt, toSignInputs) = try PsbtBuilder.build(
                [
                    UTXO.gen(pk: from, addressType: type, satoshis: 10_000),
                    UTXO.gen(pk: from, addressType: type, satoshis: 1_000)
                ],
                to: [to.toAddress(type: type)],
                toAmount: [1_000],
                change: from.toAddress(type: type),
                feeRate: 1
            )

            try from.sign(psbt, options: toSignInputs)

            XCTAssertEqual(psbt.inputs.count, 1)
            XCTAssertEqual(psbt.outputs.count, 2)
        }
    }

    func testBuild_3() throws {
        try addressTypes.forEach { type in
            let (psbt, toSignInputs) = try PsbtBuilder.build(
                [
                    UTXO.gen(pk: from, addressType: type, satoshis: 5_000),
                    UTXO.gen(pk: from, addressType: type, satoshis: 5_000),
                    UTXO.gen(pk: from, addressType: type, satoshis: 10_000)
                ],
                to: [to.toAddress(type: type)],
                toAmount: [10_000],
                change: from.toAddress(type: type),
                feeRate: 1
            )

            try from.sign(psbt, options: toSignInputs)

            XCTAssertEqual(psbt.inputs.count, 3)
            XCTAssertEqual(psbt.outputs.count, 2)
        }
    }

    func testInsufficent() throws {
        addressTypes.forEach { type in
            do {
                let (_, _) = try PsbtBuilder.build(
                    [
                        UTXO.gen(pk: from, addressType: type, satoshis: 5_000),
                        UTXO.gen(pk: from, addressType: type, satoshis: 5_000),
                        UTXO.gen(pk: from, addressType: type, satoshis: 278)
                    ],
                    to: [to.toAddress(type: type)],
                    toAmount: [10_000],
                    change: from.toAddress(type: type),
                    feeRate: 1
                )
            } catch {
                XCTAssertEqual(error as! PsbtBuilder.BuilderError, PsbtBuilder.BuilderError.insufficientUTXO)
            }
        }
    }

    func testMultiReceiver() throws {
        try addressTypes.forEach { type in
            let (psbt, toSignInputs) = try PsbtBuilder.build(
                [
                    UTXO.gen(pk: from, addressType: type, satoshis: 10_000)
                ],
                to: [
                    to.toAddress(type: type),
                    to.toAddress(type: type)
                ],
                toAmount: [
                    1_000,
                    5_000
                ],
                change: from.toAddress(type: type),
                feeRate: 1
            )

            try from.sign(psbt, options: toSignInputs)
            let fee = psbt.fee
            let tx = psbt.extractTransaction()
            let virtualSize = tx.virtualSize
            let finalFeeRate = Double(fee) / Double(virtualSize)

            XCTAssertEqual(psbt.inputs.count, 1)
            XCTAssertEqual(psbt.outputs.count, 3)
            expectFeeRate(type: type, rate1: finalFeeRate, rate2: 1)
        }
    }

    func testManyUTXOs() throws {
        try addressTypes.forEach { type in
            let inputs = (0..<1000).map { _ in
                UTXO.gen(pk: from, addressType: type, satoshis: 1_000)
            }
            let (psbt, toSignInputs) = try PsbtBuilder.build(
                inputs,
                to: [to.toAddress(type: type)],
                toAmount: [500_000],
                change: from.toAddress(type: type),
                feeRate: 1
            )

            try from.sign(psbt, options: toSignInputs)
            let fee = psbt.fee
            let tx = psbt.extractTransaction()
            let virtualSize = tx.virtualSize
            let finalFeeRate = Double(fee) / Double(virtualSize)

            XCTAssertEqual(tx.outputs[0].lockingScript, to.toAddress(type: type).script)
            XCTAssertEqual(tx.outputs[0].value, 500_000)
            expectFeeRate(type: type, rate1: finalFeeRate, rate2: 1)
        }
    }
}
