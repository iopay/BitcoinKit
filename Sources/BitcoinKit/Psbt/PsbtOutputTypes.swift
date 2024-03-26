//
//  PsbtOutputTypes.swift
//  
//
//  Created by liugang zhang on 2024/3/26.
//

import Foundation

public enum PsbtOutputTypes: UInt8, CaseIterable {
  case REDEEM_SCRIPT
  case WITNESS_SCRIPT
  case BIP32_DERIVATION // multiple OK, key contains pubkey
  case TAP_INTERNAL_KEY = 0x05
  case TAP_TREE
  case TAP_BIP32_DERIVATION // multiple OK, key contains x-only pubkey
}
