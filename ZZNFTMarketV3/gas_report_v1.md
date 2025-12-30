# ZZNFTMarketV3 Gas Report V1 (Baseline)

**Date**: 2025-12-30  
**Solidity Version**: 0.8.30  
**Tests Passed**: 14/14

---

## Summary

| Contract | Deployment Cost | Deployment Size |
|----------|-----------------|-----------------|
| ZZNFTMarketV3 | 2,364,642 | 12,666 bytes |

---

## ZZNFTMarketV3 Function Gas Usage

| Function | Min | Avg | Median | Max | # Calls |
|----------|-----|-----|--------|-----|---------|
| **list** | 28,207 | 230,642 | 232,298 | 232,298 | 268 |
| **buyNFT** | 31,529 | 73,505 | 73,505 | 115,481 | 2 |
| **permitBuy** | 28,747 | 144,918 | 146,750 | 151,538 | 263 |
| setSigner | 24,183 | 27,438 | 27,438 | 30,693 | 2 |
| getNonce | 2,874 | 2,874 | 2,874 | 2,874 | 263 |
| getDomainSeparator | 510 | 510 | 510 | 510 | 262 |
| signer | 2,531 | 2,531 | 2,531 | 2,531 | 1 |

---

## Test Results (Gas per Test)

| Test | Gas Used |
|------|----------|
| test_List_Success_EmitsEvent | 303,776 |
| test_BuyNFT_Success | 456,432 |
| test_PermitBuy_Success | 530,513 |
| test_PermitBuy_Fail_ReplayAttack | 547,342 |
| test_PermitBuy_Fail_WrongListingId | 672,127 |
| test_PermitBuy_Fail_WrongBuyer | 490,182 |
| test_PermitBuy_Fail_InvalidSignature | 436,544 |
| test_PermitBuy_Fail_ExpiredDeadline | 404,619 |
| test_BuyNFT_Fail_BuySelf | 377,424 |
| test_List_Fail_ZeroPrice | 98,654 |
| test_List_Fail_NotOwner | 52,119 |
| test_SetSigner_Success | 46,448 |
| test_SetSigner_Fail_NotAdmin | 35,389 |

---

## Key Observations

1. **`list()` function**: Median cost of 232,298 gas - includes NFT transfer (safeTransferFrom) and storage writes for Listing struct
2. **`buyNFT()` function**: Median cost of 73,505 gas (when successful, max is 115,481) - includes ERC20 transfer and NFT transfer
3. **`permitBuy()` function**: Median cost of 146,750 gas - includes signature verification, ERC20 transfer, and NFT transfer
4. **Deployment**: 2,364,642 gas (~12.6KB bytecode)
