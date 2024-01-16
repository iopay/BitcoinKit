//
//  TransactionTests.swift
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

import XCTest
@testable import BitcoinKit

class TransactionTests: XCTestCase {
    func testSignTransaction1() {
        // Transaction in testnet3
        // https://api.blockcypher.com/v1/btc/test3/txs/0189910c263c4d416d5c5c2cf70744f9f6bcd5feaf0b149b02e5d88afbe78992
        let prevTxID = "1524ca4eeb9066b4765effd472bc9e869240c4ecb5c1ee0edb40f8b666088231"
        let hash = Data(Data(hex: prevTxID).reversed())
        let index: UInt32 = 1
        let outpoint = TransactionOutPoint(hash: hash, index: index)

        let balance: UInt64 = 169012961
        let amount: UInt64  =  50000000
        let fee: UInt64     =  10000000
        let change: UInt64     =  balance - amount - fee
        let toAddress = try! BitcoinAddress(legacy: "mv4rnyY3Su5gjcDNzbMLKBQkBicCtHUtFB") // https://testnet.coinfaucet.eu/en/

        let privateKey = try! PrivateKey(wif: "92pMamV6jNyEq9pDpY4f6nBy9KpV2cfJT4L5zDUYiGqyQHJfF1K")
        let changeAddress = privateKey.publicKey().toBitcoinAddress()

        let lockScript = Script(address: changeAddress)!.data
        let output = TransactionOutput(value: 169012961, lockingScript: lockScript)
        let unspentTransaction = UnspentTransaction(output: output, outpoint: outpoint)
        let plan = TransactionPlan(unspentTransactions: [unspentTransaction], amount: amount, fee: fee, change: change)
        let transaction = TransactionBuilder.build(from: plan, toAddress: toAddress, changeAddress: changeAddress)
        let sighashHelper = BTCSignatureHashHelper(hashType: .ALL)
        let sighash = sighashHelper.createSignatureHash(of: transaction, for: unspentTransaction.output, inputIndex: 0)
        XCTAssertEqual(sighash.hex, "fd2f20da1c28b008abcce8a8ac7e1a7687fc944e001a24fc3aacb6a7570a3d0f")
        let signature = privateKey.sign(sighash)
        XCTAssertEqual(signature.hex, "3044022074ddd327544e982d8dd53514406a77a96de47f40c186e58cafd650dd71ea522702204f67c558cc8e771581c5dda630d0dfff60d15e43bf13186669392936ec539d03")
        let signer = TransactionSigner(unspentTransactions: plan.unspentTransactions, transaction: transaction, sighashHelper: BTCSignatureHashHelper(hashType: .ALL))
        let signedTransaction = try! signer.sign(with: [privateKey])
        XCTAssertEqual(signedTransaction.serialized().hex, "010000000131820866b6f840db0eeec1b5ecc44092869ebc72d4ff5e76b46690eb4eca2415010000008a473044022074ddd327544e982d8dd53514406a77a96de47f40c186e58cafd650dd71ea522702204f67c558cc8e771581c5dda630d0dfff60d15e43bf13186669392936ec539d030141047e000cc16c9a4d38cb1572b9dc34c1452626aa170b46150d0e806be1b42517f0832c8a58f543128083ffb8632bae94dd5f3e1e89fad0a17f64ed8bbbb90b5753ffffffff0280f0fa02000000001976a9149f9a7abd600c0caa03983a77c8c3df8e062cb2fa88ace1677f06000000001976a9142a539adfd7aefcc02e0196b4ccf76aea88a1f47088ac00000000")
        XCTAssertEqual(signedTransaction.txID, "0189910c263c4d416d5c5c2cf70744f9f6bcd5feaf0b149b02e5d88afbe78992")
    }

    func testSignTransaction2() {
        // Transaction on Bitcoin Cash Mainnet
        // TxID : 96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4
        // https://explorer.bitcoin.com/bch/tx/96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4
        let toAddress: BitcoinAddress = try! BitcoinAddress(legacy: "1Bp9U1ogV3A14FMvKbRJms7ctyso4Z4Tcx")
        let changeAddress: BitcoinAddress = try! BitcoinAddress(legacy: "1FQc5LdgGHMHEN9nwkjmz6tWkxhPpxBvBU")

        let unspentOutput = TransactionOutput(value: 5151, lockingScript: Data(hex: "76a914aff1e0789e5fe316b729577665aa0a04d5b0f8c788ac"))
        let unspentOutpoint = TransactionOutPoint(hash: Data(hex: "e28c2b955293159898e34c6840d99bf4d390e2ee1c6f606939f18ee1e2000d05"), index: 2)
        let unspentTransaction = UnspentTransaction(output: unspentOutput, outpoint: unspentOutpoint)
        let utxoKey = try! PrivateKey(wif: "L1WFAgk5LxC5NLfuTeADvJ5nm3ooV3cKei5Yi9LJ8ENDfGMBZjdW")

        let feePerByte: UInt64 = 1
        let planner = TransactionPlanner(feePerByte: feePerByte)
        let plan = planner.plan(unspentTransactions: [unspentTransaction], target: 600)
        let transaction = TransactionBuilder.build(from: plan, toAddress: toAddress, changeAddress: changeAddress)
        
        let signer = TransactionSigner(unspentTransactions: plan.unspentTransactions, transaction: transaction, sighashHelper: BCHSignatureHashHelper(hashType: .ALL))
        let signedTransaction = try! signer.sign(with: [utxoKey])

        XCTAssertEqual(signedTransaction.txID, "96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4")
        XCTAssertEqual(signedTransaction.serialized().hex, "0100000001e28c2b955293159898e34c6840d99bf4d390e2ee1c6f606939f18ee1e2000d05020000006b483045022100b70d158b43cbcded60e6977e93f9a84966bc0cec6f2dfd1463d1223a90563f0d02207548d081069de570a494d0967ba388ff02641d91cadb060587ead95a98d4e3534121038eab72ec78e639d02758e7860cdec018b49498c307791f785aa3019622f4ea5bffffffff0258020000000000001976a914769bdff96a02f9135a1d19b749db6a78fe07dc9088ace5100000000000001976a9149e089b6889e032d46e3b915a3392edfd616fb1c488ac00000000")
    }

    func testIsCoinbase() {
        let data = Data(hex: "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff010000000000000000015100000000")
        let tx = Transaction.deserialize(data)
        XCTAssert(tx.isCoinbase())
    }

    func testSignWitness() throws {
        let pk = try PrivateKey(wif: "cMaiBc8cCbUcM4uyBCHfDabidYUR8EACuSm9rgRkxQPCsBma4sbX")
        let s1 = try Script().append(.OP_0).appendData(Data(hex: "806738d85849e50bce67d5d9d4dd7fb025ffd972")).data
        let s2 = try Script().append(.OP_0).appendData(Data(hex: "e5495ffe01a0598c25d2470d56742effe75237a7")).data
        let balance: UInt64 = 116000
        let amount: UInt64  = 10000
        let fee: UInt64 = 22968

        let utxos = [
            TransactionOutPoint(hash: Data(Data(hex: "a42e65df3ced1c950bcc5612d4599692143987c3869c817f49b41d402218b983").reversed()), index: 2),
            TransactionOutPoint(hash: Data(Data(hex: "669634d8d40559c8b14037680e1b81b1981f285f62f3b8a95806aa74febd9378").reversed()), index: 7),
            TransactionOutPoint(hash: Data(Data(hex: "31f788003fbc05424bf57d044228e82b34f81d401fe31291838973823bcd6d43").reversed()), index: 0)
        ]

        let inputs = utxos.map {
            TransactionInput(previousOutput: $0, sequence: UInt32.max)
        }
        let outputs = [
            TransactionOutput(value: amount, lockingScript: s2),
            TransactionOutput(value: balance - amount - fee, lockingScript: s1)
        ]
        let unspent = [
            UnspentTransaction(output: .init(value: 8000, lockingScript: s1), outpoint: utxos[0]),
            UnspentTransaction(output: .init(value: 8000, lockingScript: s1), outpoint: utxos[1]),
            UnspentTransaction(output: .init(value: 100000, lockingScript: s1), outpoint: utxos[2])
        ]
        let tx = Transaction(version: 2, inputs: inputs, outputs: outputs, lockTime: 0)
        let signer = TransactionSigner(unspentTransactions: unspent, transaction: tx, sighashHelper: BTCSignatureHashHelper(hashType: .ALL))
        let signedTx = try signer.sign(with: [pk])
        print(signedTx.serialized().hex)
        XCTAssertEqual(signedTx.serialized().hex, "0200000000010383b91822401db4497f819c86c3873914929659d41256cc0b951ced3cdf652ea40200000000ffffffff7893bdfe74aa0658a9b8f3625f281f98b1811b0e683740b1c85905d4d83496660700000000ffffffff436dcd3b827389839112e31f401df8342be82842047df54b4205bc3f0088f7310000000000ffffffff021027000000000000160014e5495ffe01a0598c25d2470d56742effe75237a75844010000000000160014806738d85849e50bce67d5d9d4dd7fb025ffd97202483045022100c613ee699949584b5bc92b6157786e004a1a69de72ec3cacae8ddafb4b6c97eb0220541a0f1b1f405710ed4aa67cd74d0d009a4bd21a2716cbaba04d5f5c043014a501210330d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a590247304402204fc4e885039f6772a5a5708fbc34889801774ebd75b568ea4866cc97a8e9b6ee02201be3fa0d5fb890a7228e60f38cbd5c9d9d0568d0732945647f3672c357f0e72401210330d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a5902483045022100fdc44fbc6dd2268c878b8a11b92f1abe36ca983889cb23e68ce2dd14f64ce6da02200b1bef64fef7bd00a93ea625cfb63f3dd9a227c4b29a7ec970f5e58a800fbd6301210330d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a5900000000")
    }
}
