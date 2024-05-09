//
//  Bip371.swift
//
//
//  Created by liugang zhang on 2024/5/8.
//

import Foundation

public func toXOnly(_ data: Data) -> Data {
    data.count == 32 ? data : data.dropFirst()
}

extension PsbtInputUpdate {
    public func finalizeTapScript(with tapLeafHashToFinalize: Data? = nil) throws -> Data {
        let tapLeaf = try findTapLeafToFinalize(with: tapLeafHashToFinalize)

        let sigs = sortSignatures(with: tapLeaf)
        let witness = sigs + [tapLeaf.script, tapLeaf.controlBlock]
        return witnessStackToScriptWitness(witness: witness)
    }

    public func sortSignatures(with tapLeaf: TapLeafScript) -> [Data] {
        let leafHash = tapLeaf.leafHash
        return tapScriptSig?
            .filter { $0.leafHash == leafHash }
            .map { ($0, pubkeyPositionInScript(pubkey: $0.pubKey, script: tapLeaf.script)) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0.signature }
            ?? []
    }

    public func findTapLeafToFinalize(with tapLeafHashToFinalize: Data?) throws -> TapLeafScript {
        guard let sig = tapScriptSig, !sig.isEmpty else {
            throw PsbtError.cannotFinalize
        }
        let tapLeaf = tapLeafScript?.sorted { $0.controlBlock.count > $1.controlBlock.count }
            .first { canFinalizeLeaf(leaf: $0, tapScriptSig: sig, hash: tapLeafHashToFinalize) }
        guard let tapLeaf else {
            throw PsbtError.cannotFinalize
        }
        return tapLeaf
    }
}

extension TapLeafScript {
    public func canFinalizeLeaf(with tapScriptSig: [TapScriptSig], hash: Data?) -> Bool {
//        let leafHash = tapLeafHash(output: script, version: leafVersion)
        let whiteListedHash = hash == nil || hash == leafHash
        return tapScriptSig.first { $0.leafHash == leafHash } != nil && whiteListedHash
    }
    
    var leafHash: Data {
        tapLeafHash(output: script, version: leafVersion)
    }
}

public func findTapLeafToFinalize(input: PsbtInputUpdate, tapLeafHashToFinalize: Data?) throws -> TapLeafScript {
    guard let sig = input.tapScriptSig, !sig.isEmpty else {
        throw PsbtError.cannotFinalize
    }
    let tapLeaf = input.tapLeafScript?.sorted { $0.controlBlock.count > $1.controlBlock.count }
        .first { canFinalizeLeaf(leaf: $0, tapScriptSig: sig, hash: tapLeafHashToFinalize) }
    guard let tapLeaf else {
        throw PsbtError.cannotFinalize
    }
    return tapLeaf
}

public func canFinalizeLeaf(leaf: TapLeafScript, tapScriptSig: [TapScriptSig], hash: Data?) -> Bool {
    let leafHash = tapLeafHash(output: leaf.script, version: leaf.leafVersion)
    let whiteListedHash = hash == nil || hash == leafHash
    return tapScriptSig.first { $0.leafHash == leafHash } != nil && whiteListedHash
}
