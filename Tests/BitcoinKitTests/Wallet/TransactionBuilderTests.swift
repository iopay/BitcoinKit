//
//  TransactionBuilderTests.swift
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

import XCTest
@testable import BitcoinKit

class TransactionBuilderTests: XCTestCase {
    func testBTCTransaction() {
        // Transaction in testnet3
        // https://api.blockcypher.com/v1/btc/test3/txs/0189910c263c4d416d5c5c2cf70744f9f6bcd5feaf0b149b02e5d88afbe78992
        
        // TransactionOutput
        let prevTxLockScript = Data(hex: "76a9142a539adfd7aefcc02e0196b4ccf76aea88a1f47088ac")
        let prevTxOutput = TransactionOutput(value: 169_012_961, lockingScript: prevTxLockScript)
        
        // TransactionOutpoint
        let prevTxID = "1524ca4eeb9066b4765effd472bc9e869240c4ecb5c1ee0edb40f8b666088231"
        let prevTxHash = Data(Data(hex: prevTxID).reversed())
        let prevTxOutPoint = TransactionOutPoint(hash: prevTxHash, index: 1)
        
        // UnspentTransaction
        let unspentTransaction = UnspentTransaction(output: prevTxOutput,
                                      outpoint: prevTxOutPoint)
        let plan = TransactionPlan(unspentTransactions: [unspentTransaction], amount: 50_000_000, fee: 10_000_000, change: 109_012_961)
        let toAddress = try! createAddressFromString("mv4rnyY3Su5gjcDNzbMLKBQkBicCtHUtFB")
        let privKey = try! PrivateKey(wif: "92pMamV6jNyEq9pDpY4f6nBy9KpV2cfJT4L5zDUYiGqyQHJfF1K")
        let changeAddress = privKey.publicKey().legacy()
        let tx: Transaction = TransactionBuilder.build(from: plan, toAddress: toAddress, changeAddress: changeAddress)
        
        let expectedSerializedTx: Data = Data(hex: "010000000131820866b6f840db0eeec1b5ecc44092869ebc72d4ff5e76b46690eb4eca24150100000000ffffffff0280f0fa02000000001976a9149f9a7abd600c0caa03983a77c8c3df8e062cb2fa88ace1677f06000000001976a9142a539adfd7aefcc02e0196b4ccf76aea88a1f47088ac00000000")
        XCTAssertEqual(tx.serialized().hex, expectedSerializedTx.hex)
        // TODO: signature hash test
//        let expectedSignatureHash: Data = Data(hex: "fd2f20da1c28b008abcce8a8ac7e1a7687fc944e001a24fc3aacb6a7570a3d0f")
//        XCTAssertEqual(tx.signatureHash(for: prevTxOutput, inputIndex: 0, hashType: SighashType.BTC.ALL), expectedSignatureHash)
    }

    func testBuildTransaction() throws {
//        print(UInt32.max)
        let pre_id = "a61a8e37eded6b5ad276d0909638cacafcc7e39de49b313f2b6a659802452ab6"
        let preHash = Data(Data(hex: pre_id).reversed())


        let privateKey = try PrivateKey(wif: "cMaiBc8cCbUcM4uyBCHfDabidYUR8EACuSm9rgRkxQPCsBma4sbX")
        let from = privateKey.publicKey().legacy()
        let to = try createAddressFromString("n2RJwAYq4km2RPXKRKKiCR4mJZ5f9harCD")
        let balance: UInt64 = 4158265
        let amount: UInt64  = 1000000
        let fee: UInt64     = 1000 * 120

        print(preHash.hex)

        XCTAssertEqual("76a914806738d85849e50bce67d5d9d4dd7fb025ffd97288ac", Script(address: from)!.data.hex)
        XCTAssertEqual("76a914e5495ffe01a0598c25d2470d56742effe75237a788ac", Script(address: to)!.data.hex)

        let outputPoint = TransactionOutPoint(hash: preHash, index: 8)
        let utxo = UnspentTransaction(output: .init(value: balance, lockingScript: Data(hex: "76a914806738d85849e50bce67d5d9d4dd7fb025ffd97288ac")), outpoint: outputPoint)

        let input = TransactionInput(previousOutput: outputPoint, sequence: UInt32.max)
        input.update.witnessUtxo = .init(value: balance, lockingScript: Data(hex: "76a914806738d85849e50bce67d5d9d4dd7fb025ffd97288ac"))

        let output1 = TransactionOutput(value: amount, lockingScript: Script(address: to)!.data)
        let output2 = TransactionOutput(value: balance - amount - fee, lockingScript: Script(address: from)!.data)
        let tx = Transaction(version: 1, inputs: [input], outputs: [output1, output2], lockTime: 0)
//        let utxoToSign = TransactionOutput(value: balance, lockingScript: Script(address: from)!.data)

//        print(UInt8(1).littleEndian)
//        print(tx.serialized().hex)
        XCTAssertEqual(tx.serialized().hex, "0100000001b62a450298656a2b3f319be49de3c7fccaca389690d076d25a6beded378e1aa60800000000ffffffff0240420f00000000001976a914e5495ffe01a0598c25d2470d56742effe75237a788ac395c2e00000000001976a914806738d85849e50bce67d5d9d4dd7fb025ffd97288ac00000000")

        let helper = BTCSignatureHashHelper(hashType: .ALL)
        let signer = TransactionSigner(transaction: tx, sighashHelper: helper)
        let signedTx = try signer.sign(with: [privateKey])

//        let signed = privateKey.sign(signHash)
        print("rawData:", signedTx.serialized().hex)

//        print("signHash:", signHash.hex)
//        print("signed:", signed.hex)
//        print((signHash + signed).hex)
    }
}
//8564a4885d46884ca418de014a2b25b3e2a8fe1b22c4dc365b1a3e7418b7acd53045022100e9f86f57864a6aabc6e3c6606f7acc3e5c5b6b47cec46330f9d0f5f73ef5264d02204518052a11b9ade5ce479b43fb62cf11bf995e42e23cb0ce8d172be88627e16a
//3044022029ed977d19800147692b3ca015c90484db1758f56fc9d82b8f9340c808e5457502204f81feec5818c62ce5f01acd073ca04d26bbba4c028d8b63ec321e3084863d398564a4885d46884ca418de014a2b25b3e2a8fe1b22c4dc365b1a3e7418b7acd5
func splitStringIntoChunks(of size: Int, from input: String) -> [String] {
    var result = [String]()
    let characters = Array(input)
    for i in stride(from: 0, to: characters.count, by: size) {
        let end = i + size < characters.count ? i + size : characters.count
        let chunk = String(characters[i..<end])
        result.append(chunk)
    }
    return result
}
