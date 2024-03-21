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
        let toAddress = try! createAddressFromString("mv4rnyY3Su5gjcDNzbMLKBQkBicCtHUtFB") // https://testnet.coinfaucet.eu/en/

        let privateKey = try! PrivateKey(wif: "92pMamV6jNyEq9pDpY4f6nBy9KpV2cfJT4L5zDUYiGqyQHJfF1K")
        let changeAddress = privateKey.publicKey().legacy()

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

    func testSignTransaction2() throws {
        // Transaction on Bitcoin Cash Mainnet
        // TxID : 96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4
        // https://explorer.bitcoin.com/bch/tx/96ee20002b34e468f9d3c5ee54f6a8ddaa61c118889c4f35395c2cd93ba5bbb4
        let toAddress = try createAddressFromString("1Bp9U1ogV3A14FMvKbRJms7ctyso4Z4Tcx")
        let changeAddress = try createAddressFromString("1FQc5LdgGHMHEN9nwkjmz6tWkxhPpxBvBU")

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

    func testP2trWitness() throws {
        let script = Data(hex: "5120a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c")
        let signature = Data(hex: "c2fb7bc88374ac6577d37c90afe37fee740b2d824153148fb3658004de06e1283e85d28e8ac6c6acb26d7a42bad7a4f2cc358a3f8f2c950fac11523a9c69d7d8")

        XCTAssertEqual(p2trWitness(script: script, signature: signature)[0], signature)
    }

    func testSignTaproot() throws {
//        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about".split(separator: " ").map(String.init)
//        let path = "m/86'/0'/0'/0/0"
//
//        HDWallet(mnemonic: mnemonic, passphrase: "", externalIndex: <#T##UInt32#>, internalIndex: <#T##UInt32#>, network: <#T##Network#>)
        let privateKey = PrivateKey(data: Data(hex: "41f41d69260df4cf277826a9b65a3717e4eeddbeedf637f212ca096576479361"), network: .mainnetBTC)
        let xOnlyPubKey = privateKey.publicKey().xOnly
        let taproot = privateKey.publicKey().taproot()
        XCTAssertEqual(xOnlyPubKey.hex, "cc8a4bc64d897bddc5fbc2f670f7a8ba0b386779106cf1223c6fc5d7cd6fc115")
        XCTAssertEqual(taproot.address, "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr")
        XCTAssertEqual(taproot.output.hex, "5120a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c")
        let tweakedPk = privateKey.tweak(taggedHash(.TapTweak, data: xOnlyPubKey))
        XCTAssertEqual(tweakedPk.publicKey().data.hex, "03a60869f0dbcf1dc659c9cecbaf8050135ea9e8cdc487053f1dc6880949dc684c")

        let hash = "2c4d6432ab44e090dafbe8f7b1aabd8fc094567208ab09c1170d3e31989589e7"
        let index: UInt32 = 6
        let amount: UInt64 = 420000
        let sendAmount: UInt64 = 410000

        let utxos = [
            TransactionOutPoint(hash: Data(Data(hex: hash).reversed()), index: index),
        ]
        let inputs = utxos.map {
            TransactionInput(previousOutput: $0, sequence: UInt32.max)
        }
        let outputs = [
            TransactionOutput(value: sendAmount, lockingScript: Data(hex: "0014efddfdb4cd5211ccd5457e6c237cabcad14d4f39")),
//            TransactionOutput(value: balance - amount - fee, lockingScript: s1)
        ]
        var preOutput = TransactionOutput(value: amount, lockingScript: taproot.output)
        let unspent = [
            UnspentTransaction(output: preOutput, outpoint: utxos[0], tapInternalKey: xOnlyPubKey)
        ]
        let tx = Transaction(version: 2, inputs: inputs, outputs: outputs, lockTime: 0)
        let signer = TransactionSigner(unspentTransactions: unspent, transaction: tx, sighashHelper: BTCSignatureHashHelper(hashType: .ALL))
        let signedTx = try signer.sign(with: [tweakedPk])

        XCTAssertEqual(signedTx.serialized().hex, "02000000000101e7899598313e0d17c109ab08725694c08fbdaab1f7e8fbda90e044ab32644d2c0600000000ffffffff019041060000000000160014efddfdb4cd5211ccd5457e6c237cabcad14d4f3901418bf585361c5cd75bc7bf173bfefcb4b9802e5c5d6bd633a60d15a1e517e153b41ab7b36dba628f31581f13df83138690073d4df7deebb171fe899ff67e705b5c0100000000")
    }

    func testTube() throws {
        let privatek = Data(hex: "fdc938f4eebd132b26eacc863c3c8581b6a6b975654f27430a054e4c160a62a5")
        let privateKey = PrivateKey(data: privatek, network: .testnetBTC)
        let taproot = privateKey.publicKey().taproot()
        XCTAssertEqual(taproot.address, "tb1pq0atv5mzazx5gv6a9mvhn3ephgc3m2sp3qgsedtzvamzehh6txnqhf2xl9")
        let xOnlyPubKey = privateKey.publicKey().xOnly
        let tweakedPk = privateKey.tweak(taggedHash(.TapTweak, data: xOnlyPubKey))

        let utxos = [
            TransactionOutPoint(hash: Data(Data(hex: "27fc7e8e805c4367392ea43a22e5c029e94cf3b5cc5d94de75a12ad8619fe155").reversed()), index: 0),
//            TransactionOutPoint(hash: Data(Data(hex: "7294c649b950af4c2a6fc7fc5441c8496e6964ca05c37d0f33afc61431cd24ea").reversed()), index: 3)
        ]
        let inputs = utxos.map {
            TransactionInput(previousOutput: $0, sequence: UInt32.max)
        }
        let unspent = utxos.enumerated().map { i, op in
            var preOutput = TransactionOutput(value: 400000, lockingScript: taproot.output)
            return UnspentTransaction(output: preOutput, outpoint: utxos[i], tapInternalKey: xOnlyPubKey)
        }
        let outputs = [
            TransactionOutput(value: 500, lockingScript: Data(hex: "51202da54b36961d1ff3b15e2b2c6b2d5e83d9f5af2d22c4c908f24d0a7356431dd1")),
            TransactionOutput(value: 0, lockingScript: Data(hex: "6a1f696f74756265000000000175646210ac1fdc213fb70a8319a94af763733b93")),
            TransactionOutput(value: 100, lockingScript: Data(hex: "51202da54b36961d1ff3b15e2b2c6b2d5e83d9f5af2d22c4c908f24d0a7356431dd1")),
            TransactionOutput(value: 399160, lockingScript: Data(hex: "512003fab65362e88d44335d2ed979c721ba311daa0188110cb56267762cdefa59a6")),
        ]

        let tx = Transaction(version: 2, inputs: inputs, outputs: outputs, lockTime: 0)
        let signer = TransactionSigner(unspentTransactions: unspent, transaction: tx, sighashHelper: BTCSignatureHashHelper(hashType: .ALL))
        let signedTx = try signer.sign(with: [tweakedPk])

        print(signedTx.serialized().hex)
    }

    func testP2sh() throws {
        let privatekey = try PrivateKey(wif: "cS9Q18GhbUtsgqHC1dSnq2kD2GXe7FDKuxm5JhFxesR3NPDbtsRz")

        let utxos = [
            TransactionOutPoint(hash: Data(Data(hex: "338e9e0357c4be9d6d583665f789dcaf4bde9b0589f5906e8a3457549016a8f0").reversed()), index: 3),
        ]
        let inputs = utxos.map {
            TransactionInput(previousOutput: $0, sequence: UInt32.max)
        }
//        let unspent = utxos.enumerated().map { i, op in
//            var preOutput = TransactionOutput(value: 49006, lockingScript: Data(hex: "a91421be9d00c3305b9e5a9eb628953ef7071c003fc687"))
//            preOutput.redeemScript = Data(hex: "0014ec535b08b689033c8afc6a3a7b46489d4f72b55c")
//            return UnspentTransaction(output: preOutput, outpoint: utxos[i])
//        }
        let outputs = [
            TransactionOutput(value: 1000, lockingScript: Data(hex: "a91421be9d00c3305b9e5a9eb628953ef7071c003fc687")),
        ]

        let unspent = utxos.map { u in
            UnspentTransaction(output: TransactionOutput(value: 49006, lockingScript: Data(hex: "a91421be9d00c3305b9e5a9eb628953ef7071c003fc687")), outpoint: u, redeemScript: Data(hex: "0014ec535b08b689033c8afc6a3a7b46489d4f72b55c"))
        }

        let tx = Transaction(version: 2, inputs: inputs, outputs: outputs, lockTime: 0)
        let signer = TransactionSigner(unspentTransactions: unspent, transaction: tx, sighashHelper: BTCSignatureHashHelper(hashType: .ALL))
        let signedTx = try signer.sign(with: [privatekey])

        print(signedTx.serialized().hex)

        XCTAssertEqual(signedTx.serialized().hex, "02000000000101f0a816905457348a6e90f589059bde4bafdc89f76536586d9dbec457039e8e330300000017160014ec535b08b689033c8afc6a3a7b46489d4f72b55cffffffff01e80300000000000017a91421be9d00c3305b9e5a9eb628953ef7071c003fc6870247304402204df97bec6b47d54f417dd94d952d5ec1f02a488f7a1250088ae1987142c7041902204038b187cdae431b2ef4a14e5851c1a7089d8e60db8fa47c214b07f0482c6fa10121038fc16615f500148a371d4052823311a321567af773c261c34dd410ce5a4e526e00000000")
    }
}
//
//6a 1f 696f74756265 01000000 01 75646210ac1fdc213fb70a8319a94af763733b93
//6a 1f 696f74756265 00000000 01 000000005c6f6e6e65637465642d6f7574707574
//6a 1f 696f74756265 00000000 01 75646210ac1fdc213fb70a8319a94af763733b93

//6a1f696f747562650000000001000000005c6f6e6e65637465642d6f7574707574
//6a1f696f74756265010000000175646210ac1fdc213fb70a8319a94af763733b93
