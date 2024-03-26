//
//  PsbtInputTypes.swift
//  
//
//  Created by liugang zhang on 2024/3/26.
//

import Foundation

public enum PsbtInputTypes: UInt8, CaseIterable {
    case NON_WITNESS_UTXO
    case WITNESS_UTXO
    case PARTIAL_SIG // multiple OK, key contains pubkey
    case SIGHASH_TYPE
    case REDEEM_SCRIPT
    case WITNESS_SCRIPT
    case BIP32_DERIVATION // multiple OK, key contains pubkey
    case FINAL_SCRIPTSIG
    case FINAL_SCRIPTWITNESS
    case POR_COMMITMENT
    case TAP_KEY_SIG = 0x13
    case TAP_SCRIPT_SIG // multiple OK, key contains x-only pubkey
    case TAP_LEAF_SCRIPT // multiple OK, key contains controlblock
    case TAP_BIP32_DERIVATION // multiple OK, key contains x-only pubkey
    case TAP_INTERNAL_KEY
    case TAP_MERKLE_ROOT
}
