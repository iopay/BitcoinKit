//
//  PrivateKey+Sign.swift
//
//
//  Created by liugang zhang on 2024/6/3.
//

import Foundation

public struct UserToSignInput {
    let index: Int
    let publicKey: String
    let sighashTypes: [BTCSighashType]?
    let disableTweakSigner: Bool?

    init(index: Int, publicKey: String, sighashTypes: [BTCSighashType]? = nil, disableTweakSigner: Bool? = nil) {
        self.index = index
        self.publicKey = publicKey
        self.sighashTypes = sighashTypes
        self.disableTweakSigner = disableTweakSigner
    }
}

extension PrivateKey {
    public func sign(_ psbt: Psbt, options: [UserToSignInput], autoFinalized: Bool = true) throws {
        try options.forEach { opt in
            if psbt.inputs[opt.index].isTaprootInput && opt.disableTweakSigner != true {
                try psbt.signInput(with: tweaked, at: opt.index, sigHashTypes: opt.sighashTypes)
            } else {
                try psbt.signInput(with: self, at: opt.index, sigHashTypes: opt.sighashTypes)
            }
        }
        if autoFinalized {
            try options.forEach { opt in
                try psbt.finalizeInput(index: opt.index)
            }
        }
    }
}
