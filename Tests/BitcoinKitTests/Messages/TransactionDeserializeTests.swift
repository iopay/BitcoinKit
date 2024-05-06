//
//  TransactionDeserializeTests.swift
//  
//
//  Created by liugang zhang on 2024/3/21.
//

import XCTest
@testable import BitcoinKit

final class TransactionDeserializeTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDeserializeUnsigned() throws {
        let hex = "0200000001f0a816905457348a6e90f589059bde4bafdc89f76536586d9dbec457039e8e330300000000ffffffff01e80300000000000017a91421be9d00c3305b9e5a9eb628953ef7071c003fc68700000000"
        let tx = Transaction.deserialize(Data(hex: hex))
        
        XCTAssertEqual(tx.version, 2)
        XCTAssertEqual(tx.inputs.count, 1)
        XCTAssertEqual(tx.outputs.count, 1)
        XCTAssertEqual(tx.inputs[0].previousOutput.hash.hex, "f0a816905457348a6e90f589059bde4bafdc89f76536586d9dbec457039e8e33")
        XCTAssertEqual(tx.inputs[0].previousOutput.index, 3)
        XCTAssertEqual(tx.outputs[0].lockingScript.hex, "a91421be9d00c3305b9e5a9eb628953ef7071c003fc687")
        XCTAssertEqual(tx.outputs[0].value, 1000)
    }

    func testDeserialPsbt() throws {
        let hex = "70736274ff0100530200000001f0a816905457348a6e90f589059bde4bafdc89f76536586d9dbec457039e8e330300000000ffffffff01e80300000000000017a91421be9d00c3305b9e5a9eb628953ef7071c003fc68700000000000101206ebf00000000000017a91421be9d00c3305b9e5a9eb628953ef7071c003fc6870104160014ec535b08b689033c8afc6a3a7b46489d4f72b55c0000"
        let psbt = try Psbt.deserialize(Data(hex: hex))
        let tx = psbt.tx

        XCTAssertEqual(tx.version, 2)
        XCTAssertEqual(tx.inputs.count, 1)
        XCTAssertEqual(tx.outputs.count, 1)
        XCTAssertEqual(tx.inputs[0].previousOutput.hash.hex, "f0a816905457348a6e90f589059bde4bafdc89f76536586d9dbec457039e8e33")
        XCTAssertEqual(tx.inputs[0].previousOutput.index, 3)
        XCTAssertEqual(tx.outputs[0].lockingScript.hex, "a91421be9d00c3305b9e5a9eb628953ef7071c003fc687")
        XCTAssertEqual(tx.outputs[0].value, 1000)

        XCTAssertEqual(psbt.serialized().hex, hex)
    }

    func testDeserialPsbt2() throws {
        let hex = "70736274ff01009a020000000275ddabb27b8845f5247975c8a5ba7c6f336c4570708ebe230caf6db5217ae8580000000000ffffffff1dea7cd05979072a3578cab271c02244ea8a090bbb46aa680a65ecd027048d830100000000ffffffff0270aaf00800000000160014d85c2b71d0060b09c9886aeb815e50991dda124d00e1f5050000000016001400aea9a2e5f0f876a588df5546e8742d1d87008f00000000000100bb0200000001aad73931018bd25f84ae400b68848be09db706eac2ac18298babee71ab656f8b0000000048473044022058f6fc7c6a33e1b31548d481c826c015bd30135aad42cd67790dab66d2ad243b02204a1ced2604c6735b6393e5b41691dd78b00f0c5942fb9f751856faa938157dba01feffffff0280f0fa020000000017a9140fb9463421696b82c833af241c78c17ddbde493487d0f20a270100000017a91429ca74f8a08f81999428185c97b5d852e4063f6187650000000104475221029583bf39ae0a609747ad199addd634fa6108559d6c5cd39b4c2183f1ab96e07f2102dab61ff49a14db6a7d02b0cd1fbb78fc4b18312b5b4e54dae4dba2fbfef536d752ae2206029583bf39ae0a609747ad199addd634fa6108559d6c5cd39b4c2183f1ab96e07f10d90c6a4f000000800000008000000080220602dab61ff49a14db6a7d02b0cd1fbb78fc4b18312b5b4e54dae4dba2fbfef536d710d90c6a4f0000008000000080010000800001012000c2eb0b0000000017a914b7f5faf40e3d40a5a459b1db3535f2b72fa921e88701042200208c2353173743b595dfb4a07b72ba8e42e3797da74e87fe7d9d7497e3b2028903010547522103089dc10c7ac6db54f91329af617333db388cead0c231f723379d1b99030b02dc21023add904f3d6dcf59ddb906b0dee23529b7ffb9ed50e5e86151926860221f0e7352ae2206023add904f3d6dcf59ddb906b0dee23529b7ffb9ed50e5e86151926860221f0e7310d90c6a4f000000800000008003000080220603089dc10c7ac6db54f91329af617333db388cead0c231f723379d1b99030b02dc10d90c6a4f00000080000000800200008000220203a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca5877110d90c6a4f0000008000000080040000802107a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca58771310103a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca587d90c6a4f000000800000008004000080002202027f6399757d2eff55a136ad02c684b1838b6556e5f1b6b34282a94b6b5005109610d90c6a4f00000080000000800500008000"
        let psbt = try Psbt.deserialize(Data(hex: hex))
        let tx = psbt.tx
        print(tx)

        XCTAssertEqual(tx.version, 2)
        XCTAssertEqual(tx.inputs.count, 2)
        XCTAssertEqual(tx.outputs.count, 2)
        XCTAssertEqual(tx.inputs[0].previousOutput.hash.hex, "75ddabb27b8845f5247975c8a5ba7c6f336c4570708ebe230caf6db5217ae858")
        XCTAssertEqual(tx.inputs[0].previousOutput.index, 0)
        XCTAssertEqual(tx.inputs[1].previousOutput.hash.hex, "1dea7cd05979072a3578cab271c02244ea8a090bbb46aa680a65ecd027048d83")
        XCTAssertEqual(tx.inputs[1].previousOutput.index, 1)

        XCTAssertEqual(psbt.inputs[0].nonWitnessUtxo?.hex, "0200000001aad73931018bd25f84ae400b68848be09db706eac2ac18298babee71ab656f8b0000000048473044022058f6fc7c6a33e1b31548d481c826c015bd30135aad42cd67790dab66d2ad243b02204a1ced2604c6735b6393e5b41691dd78b00f0c5942fb9f751856faa938157dba01feffffff0280f0fa020000000017a9140fb9463421696b82c833af241c78c17ddbde493487d0f20a270100000017a91429ca74f8a08f81999428185c97b5d852e4063f618765000000")
        XCTAssertEqual(psbt.inputs[0].redeemScript?.hex, "5221029583bf39ae0a609747ad199addd634fa6108559d6c5cd39b4c2183f1ab96e07f2102dab61ff49a14db6a7d02b0cd1fbb78fc4b18312b5b4e54dae4dba2fbfef536d752ae")
        XCTAssertEqual(psbt.inputs[0].bip32Derivation?[0].masterFingerprint.hex, "d90c6a4f")
        XCTAssertEqual(psbt.inputs[0].bip32Derivation?[0].pubkey.hex, "029583bf39ae0a609747ad199addd634fa6108559d6c5cd39b4c2183f1ab96e07f")
        XCTAssertEqual(psbt.inputs[0].bip32Derivation?[0].path, "m/0'/0'/0'")
        XCTAssertEqual(psbt.inputs[0].bip32Derivation?[1].masterFingerprint.hex, "d90c6a4f")
        XCTAssertEqual(psbt.inputs[0].bip32Derivation?[1].pubkey.hex, "02dab61ff49a14db6a7d02b0cd1fbb78fc4b18312b5b4e54dae4dba2fbfef536d7")
        XCTAssertEqual(psbt.inputs[0].bip32Derivation?[1].path, "m/0'/0'/1'")

        XCTAssertEqual(psbt.inputs[1].witnessUtxo?.lockingScript.hex, "a914b7f5faf40e3d40a5a459b1db3535f2b72fa921e887")
        XCTAssertEqual(psbt.inputs[1].witnessUtxo?.value, 200000000)
        XCTAssertEqual(psbt.inputs[1].redeemScript?.hex, "00208c2353173743b595dfb4a07b72ba8e42e3797da74e87fe7d9d7497e3b2028903")
        XCTAssertEqual(psbt.inputs[1].witnessScript?.hex, "522103089dc10c7ac6db54f91329af617333db388cead0c231f723379d1b99030b02dc21023add904f3d6dcf59ddb906b0dee23529b7ffb9ed50e5e86151926860221f0e7352ae")

        XCTAssertEqual(tx.outputs[0].lockingScript.hex, "0014d85c2b71d0060b09c9886aeb815e50991dda124d")
        XCTAssertEqual(tx.outputs[0].value, 149990000)
        XCTAssertEqual(psbt.outputs[0].bip32Derivation?[0].pubkey.hex, "03a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca58771")
        XCTAssertEqual(psbt.outputs[0].bip32Derivation?[0].masterFingerprint.hex, "d90c6a4f")
        XCTAssertEqual(psbt.outputs[0].bip32Derivation?[0].path, "m/0'/0'/4'")
        XCTAssertEqual(psbt.outputs[0].tapBip32Derivation?.count, 1)
        XCTAssertEqual(psbt.outputs[0].tapBip32Derivation?[0].leafHashes.count, 1)
        XCTAssertEqual(psbt.outputs[0].tapBip32Derivation?[0].leafHashes[0].hex, "03a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca587")
        XCTAssertEqual(psbt.outputs[0].tapBip32Derivation?[0].pubkey.hex, "a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca58771")
        XCTAssertEqual(psbt.outputs[0].tapBip32Derivation?[0].masterFingerprint.hex, "d90c6a4f")
        XCTAssertEqual(psbt.outputs[0].tapBip32Derivation?[0].path, "m/0'/0'/4'")


        XCTAssertEqual(tx.outputs[1].lockingScript.hex, "001400aea9a2e5f0f876a588df5546e8742d1d87008f")
        XCTAssertEqual(tx.outputs[1].value, 100000000)

        XCTAssertNotNil(Transaction.deserialize(psbt.inputs[0].nonWitnessUtxo!))

        XCTAssertEqual(psbt.serialized().hex, hex)
    }

    func test3() throws {
        let hex = "70736274ff01007d0200000001fda15c90970559eb21c377c3f4814ababf0b33eb43c51a0ea94a5baac85a798e0100000000ffffffff02e803000000000000160014da7fda4bd80b59b83963e7da8649963f8834fc6950f202000000000022512003fab65362e88d44335d2ed979c721ba311daa0188110cb56267762cdefa59a6000000000001012bc6f602000000000022512003fab65362e88d44335d2ed979c721ba311daa0188110cb56267762cdefa59a601084201408e76f01ab26b71d9a87eb28de5cd1029f0443172fb1d488507a2ae0963c8f66ef260c268dce90f2a4312a8a6bc1d6439df9f2bad0b30b31c25f36a22f8f2d84b000000"
        let psbt = try Psbt.deserialize(hex)
        print(psbt)
    }
}
