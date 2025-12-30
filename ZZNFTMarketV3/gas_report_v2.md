# ZZNFTMarketV3 Gas Report V2 (Optimized)

**Date**: 2025-12-30  
**Solidity Version**: 0.8.30  
**Compiler Settings**: via_ir=true, optimizer=true, optimizer_runs=200  
**Tests Passed**: 14/14

---

## Summary

| Contract | Deployment Cost | Deployment Size |
|----------|-----------------|-----------------|
| ZZNFTMarketV3 | 1,149,261 | 5,951 bytes |

---

## ZZNFTMarketV3 Function Gas Usage

| Function | Min | Avg | Median | Max | # Calls |
|----------|-----|-----|--------|-----|---------|
| **list** | 27,714 | 204,241 | 205,704 | 205,704 | 268 |
| **buyNFT** | 37,396 | 75,214 | 75,214 | 113,033 | 2 |
| **permitBuy** | 27,985 | 141,012 | 142,725 | 147,513 | 263 |
| setSigner | 23,769 | 27,026 | 27,026 | 30,284 | 2 |
| getNonce | 2,506 | 2,506 | 2,506 | 2,506 | 263 |
| getDomainSeparator | 558 | 558 | 558 | 558 | 262 |
| signer | 2,354 | 2,354 | 2,354 | 2,354 | 1 |

---

## Test Results (Gas per Test)

| Test | Gas Used |
|------|----------|
| test_List_Success_EmitsEvent | 273,948 |
| test_BuyNFT_Success | 428,051 |
| test_PermitBuy_Success | 494,503 |
| test_PermitBuy_Fail_ReplayAttack | 510,343 |
| test_PermitBuy_Fail_WrongListingId | 612,610 |
| test_PermitBuy_Fail_WrongBuyer | 461,290 |
| test_PermitBuy_Fail_InvalidSignature | 404,817 |
| test_PermitBuy_Fail_ExpiredDeadline | 367,955 |
| test_BuyNFT_Fail_BuySelf | 353,950 |
| test_List_Fail_ZeroPrice | 95,441 |
| test_List_Fail_NotOwner | 49,502 |
| test_SetSigner_Success | 45,452 |
| test_SetSigner_Fail_NotAdmin | 35,175 |

---

## Optimizations Applied

1. **Struct Packing**: Moved `bool active` next to `address seller` to share a storage slot (saves 2100+ gas per listing creation)
2. **Unchecked Arithmetic**: Used `unchecked` block for `nextListingId` and `nonce` increments (saves ~20-40 gas per call)
3. **Storage Variable Caching**: Cached frequently accessed storage variables in `buyNFT()` and `permitBuy()` (saves ~100 gas per SLOAD avoided)
4. **Reentrancy Guard Constants**: Used constants `_NOT_ENTERED` and `_ENTERED` for clarity
5. **IR-based Optimizer**: Enabled `via_ir=true` with 200 runs for better code optimization
