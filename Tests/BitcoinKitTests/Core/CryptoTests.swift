//
//  BitcoinKitTests.swift
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

class CryptoTests: XCTestCase {
    func testSHA256() {
        /* Usually, when a hash is computed within bitcoin, it is computed twice.
         Most of the time SHA-256 hashes are used, however RIPEMD-160 is also used when a shorter hash is desirable
         (for example when creating a bitcoin address).

         https://en.bitcoin.it/wiki/Protocol_documentation#Hashes
         */
        XCTAssertEqual(Crypto.sha256("hello".data(using: .ascii)!).hex, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        XCTAssertEqual(Crypto.sha256sha256("hello".data(using: .ascii)!).hex, "9595c9df90075148eb06860365df33584b75bff782a510c6cd4883a419833d50")
    }

    func testSHA256RIPEMD160() {
        XCTAssertEqual(Crypto.sha256ripemd160("hello".data(using: .ascii)!).hex, "b6a9c8c230722b7c748331a8b450f05566dc7d0f")
    }

    func testSign() {
        let msg = Data(hex: "52204d20fd0131ae1afd173fd80a3a746d2dcc0cddced8c9dc3d61cc7ab6e966")
        let pk = Data(hex: "16f243e962c59e71e54189e67e66cf2440a1334514c09c00ddcc21632bac9808")
        let privateKey = PrivateKey(data: pk)

        let signature = try? Crypto.sign(msg, privateKey: privateKey)

        XCTAssertNotNil(signature)
        XCTAssertEqual(signature?.hex, "3044022055f4b20035cbb2e85b7a04a0874c80d5822758f4e47a9a69db04b29f8b218f920220491e6a13296cfe2186da3a3ca565a179def3808b12d184553a8e3acfe1467273")
    }
    
    func testHMAC() {
        let testStr = "param1=val1&param2=val2"
        let secretKey = "password"
        let result = Crypto.hmacsha512(data: testStr.data(using: .utf8)!, key: secretKey.data(using: .utf8)!)
        XCTAssertEqual(result?.hex, "051464ad12cd03cf6c0f968317dfcededafeb8a267d6da7869e0588aa887bde6f4f0fe2077aed2a32a748c9e2d59ddc2bb7c3f034a4aa9fc9b0752c750daae94")
    }

    func testSignSchnorr() throws {
        let pk = try PrivateKey(wif: "cMaiBc8cCbUcM4uyBCHfDabidYUR8EACuSm9rgRkxQPCsBma4sbX")

        XCTAssertEqual(pk.tweaked.data.hex, "1b35e8a6a1b43af6295e9f13734e54e77be515ca490729accc6d99d43ab4824c")
        XCTAssertEqual(pk.publicKey().data.sha256().hex, "bd4dabd41b0ea82c40c8acede2279cc756e156fb1947259a036e87e5fc37cb4e")
        try XCTAssertEqual(_Crypto.signSchnorr(pk.publicKey().data.sha256(), with: pk.tweaked.data).hex, "28cb00079c9f4e7cf7deae769c9d9e4f7e2e3e003f252e96e8838eece4d82fb3b667280afad442891f9b3fea04936e18bbe9f6a11106e69fb73ab47f350ac001")

        try XCTAssertEqual(_Crypto.signSchnorr(
            Data(hex: "7e2d58d8b3bcdf1abadec7829054f90dda9805aab56c77333024b9d0a508b75c"),
            with: Data(hex: "c90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b14e5c9"),
            extra: Data(hex: "c87aa53824b4d7ae2eb035a2b5bbbccc080e76cdc6d1692c4b0b62d798e6d906")
        ).hex, "5831aaeed7b44bb74e5eab94ba9d4294c49bcf2a60728d8b4c200f50dd313c1bab745879a5ad954a72c45a91c3a51d3c7adea98d82f8481e0e1e03674a6f3fb7")

        try XCTAssertEqual(_Crypto.signSchnorr(
            Data(hex: "0000000000000000000000000000000000000000000000000000000000000000"),
            with: Data(hex: "0000000000000000000000000000000000000000000000000000000000000003"),
            extra: Data(hex: "0000000000000000000000000000000000000000000000000000000000000000")
        ).hex, "e907831f80848d1069a5371b402410364bdf1c5f8307b0084c55f1ce2dca821525f66a4a85ea8b71e482a74f382d2ce5ebeee8fdb2172f477df4900d310536c0")
    }

    func testBip0322Hash() {
        XCTAssertEqual(Crypto.bip0322Hash("message").hex, "8ca090fa05878a38a0831da888481c1f3845462cc234be4ebc47541b45421ac1")
        XCTAssertEqual(Crypto.bip0322Hash("").hex, "c90c269c4f8fcbe6880f72a721ddfbf1914268a794cbb21cfafee13770ae19f1")
        XCTAssertEqual(Crypto.bip0322Hash("Hello World").hex, "f0eb03b1a75ac6d9847f55c624a99169b5dccba2a31f5b23bea77ba270de0a7a")
    }

    func testSignMessage() throws {
        let key = try PrivateKey(wif: "cW62cANWa6wXmGPvLMUziJY9Y92apyqRcoopqLfdbaBQw58UMziF")
        let signed = Crypto.signMessage("hello world~", privateKey: key)
        XCTAssertEqual(signed, "IPMGDtIM+fTrJ5ynw002g5679BLQOn+B4RMS8i5xSwMMT+gW5TZCpgdCbh0v6tt8iHYlj+xKr4Rc5NNp76XATJ8=")
    }

    func testSignMessageOfBIP322Simple() throws {
        let key = try PrivateKey(wif: "cW62cANWa6wXmGPvLMUziJY9Y92apyqRcoopqLfdbaBQw58UMziF")
        let signed = try Crypto.signMessageOfBIP322Simple("hello world~", address: "tb1pq0atv5mzazx5gv6a9mvhn3ephgc3m2sp3qgsedtzvamzehh6txnqhf2xl9", network: .testnetBTC, privateKey: key)
        XCTAssertEqual(signed, "AUB7TMvppOpNXMOdGN8CXtyRTR9A/DJqbCoWj9epwHNJBxCDN9EWdfs/76zRvqfV7bjM1HIk7UutmMW13vvfZ3+F")
    }

    func testSignMessageOfBIP322Simple2() throws {
//        let s1 = try Crypto.signMessageOfBIP322Simple("", address: "bc1q9vza2e8x573nczrlzms0wvx3gsqjx7vavgkx0l", network: .mainnetBCH, privateKey: PrivateKey(wif: "L3VFeEujGtevx9w18HD1fhRbCH67Az2dpCymeRE1SoPK6XQtaN2k"))
//        XCTAssertEqual(s1, "AkcwRAIgM2gBAQqvZX15ZiysmKmQpDrG83avLIT492QBzLnQIxYCIBaTpOaD20qRlEylyxFSeEA2ba9YOixpX8z46TSDtS40ASECx/EgAxlkQpQ9hYjgGu6EBCPMVPwVIVJqO4XCsMvViHI=")
//        
//        let s2 = try Crypto.signMessageOfBIP322Simple("Hello World", address: "bc1q9vza2e8x573nczrlzms0wvx3gsqjx7vavgkx0l", network: .mainnetBCH, privateKey: PrivateKey(wif: "L3VFeEujGtevx9w18HD1fhRbCH67Az2dpCymeRE1SoPK6XQtaN2k"))
//        XCTAssertEqual(s2, "AkcwRAIgZRfIY3p7/DoVTty6YZbWS71bc5Vct9p9Fia83eRmw2QCICK/ENGfwLtptFluMGs2KsqoNSk89pO7F29zJLUx9a/sASECx/EgAxlkQpQ9hYjgGu6EBCPMVPwVIVJqO4XCsMvViHI=")
    }
}
