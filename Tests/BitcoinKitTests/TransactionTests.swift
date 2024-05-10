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

    func testSignWitness() throws {
        let pk = try PrivateKey(wif: "cMaiBc8cCbUcM4uyBCHfDabidYUR8EACuSm9rgRkxQPCsBma4sbX")
        let s1 = try Script().append(.OP_0).appendData(Data(hex: "806738d85849e50bce67d5d9d4dd7fb025ffd972")).data
        let s2 = try Script().append(.OP_0).appendData(Data(hex: "e5495ffe01a0598c25d2470d56742effe75237a7")).data
        let balance: UInt64 = 116000
        let amount: UInt64  = 10000
        let fee: UInt64 = 22968

        let psbt = Psbt()
        psbt.addInput(
            prevOutput: TransactionOutPoint(hash: Data(Data(hex: "a42e65df3ced1c950bcc5612d4599692143987c3869c817f49b41d402218b983").reversed()), index: 2),
            update: PsbtInputUpdate(witnessUtxo: .init(value: 8000, lockingScript: s1))
        )
        psbt.addInput(
            prevOutput: TransactionOutPoint(hash: Data(Data(hex: "669634d8d40559c8b14037680e1b81b1981f285f62f3b8a95806aa74febd9378").reversed()), index: 7),
            update: PsbtInputUpdate(witnessUtxo: .init(value: 8000, lockingScript: s1))
        )
        psbt.addInput(
            prevOutput: TransactionOutPoint(hash: Data(Data(hex: "31f788003fbc05424bf57d044228e82b34f81d401fe31291838973823bcd6d43").reversed()), index: 0),
            update: PsbtInputUpdate(witnessUtxo: .init(value: 100000, lockingScript: s1))
        )
        psbt.addOutput(output: .init(value: amount, lockingScript: s2))
        psbt.addOutput(output: .init(value: balance - amount - fee, lockingScript: s1))
        try psbt.signAllInputs(with: pk)
        try psbt.finalizeAllInputs()

        let signedTx = psbt.extractTransaction()
        print(signedTx.serialized().hex)
        XCTAssertEqual(signedTx.serialized().hex, "0200000000010383b91822401db4497f819c86c3873914929659d41256cc0b951ced3cdf652ea40200000000ffffffff7893bdfe74aa0658a9b8f3625f281f98b1811b0e683740b1c85905d4d83496660700000000ffffffff436dcd3b827389839112e31f401df8342be82842047df54b4205bc3f0088f7310000000000ffffffff021027000000000000160014e5495ffe01a0598c25d2470d56742effe75237a75844010000000000160014806738d85849e50bce67d5d9d4dd7fb025ffd97202483045022100c613ee699949584b5bc92b6157786e004a1a69de72ec3cacae8ddafb4b6c97eb0220541a0f1b1f405710ed4aa67cd74d0d009a4bd21a2716cbaba04d5f5c043014a501210330d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a590247304402204fc4e885039f6772a5a5708fbc34889801774ebd75b568ea4866cc97a8e9b6ee02201be3fa0d5fb890a7228e60f38cbd5c9d9d0568d0732945647f3672c357f0e72401210330d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a5902483045022100fdc44fbc6dd2268c878b8a11b92f1abe36ca983889cb23e68ce2dd14f64ce6da02200b1bef64fef7bd00a93ea625cfb63f3dd9a227c4b29a7ec970f5e58a800fbd6301210330d42b56c08f4f9a0fea1d0ac9993a47d5f81873b6d9512c25a749db49104a5900000000")
    }

    func testP2trWitness() throws {
        let script = Data(hex: "5120a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c")
        let signature = Data(hex: "c2fb7bc88374ac6577d37c90afe37fee740b2d824153148fb3658004de06e1283e85d28e8ac6c6acb26d7a42bad7a4f2cc358a3f8f2c950fac11523a9c69d7d8")

        XCTAssertEqual(p2trWitness(script: script, signature: signature)[0], signature)
    }

    func testSignTaproot() throws {
        let privateKey = PrivateKey(data: Data(hex: "41f41d69260df4cf277826a9b65a3717e4eeddbeedf637f212ca096576479361"), network: .mainnetBTC)
        let xOnlyPubKey = privateKey.publicKey().xOnly
        let taproot = privateKey.publicKey().taproot()
        XCTAssertEqual(xOnlyPubKey.hex, "cc8a4bc64d897bddc5fbc2f670f7a8ba0b386779106cf1223c6fc5d7cd6fc115")
        XCTAssertEqual(taproot.address, "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr")
        XCTAssertEqual(taproot.output.hex, "5120a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c")

        let hash = "2c4d6432ab44e090dafbe8f7b1aabd8fc094567208ab09c1170d3e31989589e7"
        let index: UInt32 = 6
        let amount: UInt64 = 420000
        let sendAmount: UInt64 = 410000

        let psbt = Psbt()
        psbt.addInput(
            prevOutput: .init(hash: Data(Data(hex: hash).reversed()), index: index),
            update: .init(witnessUtxo: .init(value: amount, lockingScript: taproot.output), tapInternalKey: xOnlyPubKey)
        )
        psbt.addOutput(output: .init(value: sendAmount, lockingScript: Data(hex: "0014efddfdb4cd5211ccd5457e6c237cabcad14d4f39")))

        try psbt.signAllInputs(with: privateKey.tweaked)
        try psbt.finalizeAllInputs()

        XCTAssertEqual(psbt.extractTransaction().serialized().hex, "02000000000101e7899598313e0d17c109ab08725694c08fbdaab1f7e8fbda90e044ab32644d2c0600000000ffffffff019041060000000000160014efddfdb4cd5211ccd5457e6c237cabcad14d4f39014013d57d741075765273f62f872653a61cdbf614e8add83964a231d2369c9020b48bf01e37adcf2b0887f56f854b76be4b3cc57e8b8c22fd213ff1c69b7924382200000000")
    }

    func testTube() throws {
        let privatek = Data(hex: "fdc938f4eebd132b26eacc863c3c8581b6a6b975654f27430a054e4c160a62a5")
        let privateKey = PrivateKey(data: privatek, network: .testnetBTC)
        let taproot = privateKey.publicKey().taproot()
        XCTAssertEqual(taproot.address, "tb1pq0atv5mzazx5gv6a9mvhn3ephgc3m2sp3qgsedtzvamzehh6txnqhf2xl9")
        let xOnlyPubKey = privateKey.publicKey().xOnly

        let psbt = Psbt()
        psbt.addInput(
            prevOutput: .init(hash: Data(Data(hex: "27fc7e8e805c4367392ea43a22e5c029e94cf3b5cc5d94de75a12ad8619fe155").reversed()), index: 0),
            update: .init(witnessUtxo: TransactionOutput(value: 400000, lockingScript: taproot.output), tapInternalKey: xOnlyPubKey)
        )
        psbt.addOutput(output: TransactionOutput(value: 500, lockingScript: Data(hex: "51202da54b36961d1ff3b15e2b2c6b2d5e83d9f5af2d22c4c908f24d0a7356431dd1")))
        psbt.addOutput(output: TransactionOutput(value: 0, lockingScript: Data(hex: "6a1f696f74756265000000000175646210ac1fdc213fb70a8319a94af763733b93")))
        psbt.addOutput(output: TransactionOutput(value: 100, lockingScript: Data(hex: "51202da54b36961d1ff3b15e2b2c6b2d5e83d9f5af2d22c4c908f24d0a7356431dd1")))
        psbt.addOutput(output: TransactionOutput(value: 399160, lockingScript: Data(hex: "512003fab65362e88d44335d2ed979c721ba311daa0188110cb56267762cdefa59a6")))
        try psbt.signAllInputs(with: privateKey.tweaked)
        try psbt.finalizeAllInputs()

        print(psbt.extractTransaction().serialized().hex)
    }

    func testP2sh() throws {
        let privatekey = try PrivateKey(wif: "cS9Q18GhbUtsgqHC1dSnq2kD2GXe7FDKuxm5JhFxesR3NPDbtsRz")
        let p2wpkh = privatekey.publicKey().nativeSegwit()
        let p2sh = privatekey.publicKey().nestedSegwit()
        let psbt = Psbt()
        psbt.addInput(
            prevOutput: .init(hash: Data(Data(hex: "338e9e0357c4be9d6d583665f789dcaf4bde9b0589f5906e8a3457549016a8f0").reversed()), index: 3),
            update: .init(witnessUtxo: .init(value: 49006, lockingScript: p2sh.output), redeemScript: p2wpkh.output)
        )
        psbt.addOutput(output: TransactionOutput(value: 1000, lockingScript: p2sh.output))

        try psbt.signAllInputs(with: privatekey)
        try psbt.finalizeAllInputs()

        XCTAssertEqual(psbt.extractTransaction().serialized().hex, "02000000000101f0a816905457348a6e90f589059bde4bafdc89f76536586d9dbec457039e8e330300000017160014ec535b08b689033c8afc6a3a7b46489d4f72b55cffffffff01e80300000000000017a91421be9d00c3305b9e5a9eb628953ef7071c003fc6870247304402204df97bec6b47d54f417dd94d952d5ec1f02a488f7a1250088ae1987142c7041902204038b187cdae431b2ef4a14e5851c1a7089d8e60db8fa47c214b07f0482c6fa10121038fc16615f500148a371d4052823311a321567af773c261c34dd410ce5a4e526e00000000")
    }

    func testVirtualSize() throws {
        guard let url = Bundle.module.url(forResource: "transaction", withExtension: "json") else {
            XCTFail("Missing File: transaction.json")
            return
        }

        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let valid = json["valid"] as! [[String: Any]]
        valid.forEach { item in
            let whex = item["whex"] as? String
            let hex = item["hex"] as? String
            let virtualSize = item["virtualSize"] as? Int
            let weight = item["weight"] as? Int
            if (whex != nil || hex != nil) && virtualSize != nil && weight != nil {
                let tx = if whex != nil && !whex!.isEmpty {
                    Transaction.deserialize(Data(hex: whex!))
                } else {
                    Transaction.deserialize(Data(hex: hex!))
                }
                XCTAssertEqual(tx.virtualSize, virtualSize)
                XCTAssertEqual(tx.weight, weight)
            }
        }
    }
}
