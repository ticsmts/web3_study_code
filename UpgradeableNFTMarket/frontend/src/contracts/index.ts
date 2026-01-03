import { Abi } from 'viem';

// ZZToken Upgradeable ABI
export const ZZTokenABI: Abi = [
    { name: 'name', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'string' }] },
    { name: 'symbol', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'string' }] },
    { name: 'decimals', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint8' }] },
    { name: 'balanceOf', type: 'function', stateMutability: 'view', inputs: [{ name: 'account', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
    { name: 'transfer', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ name: '', type: 'bool' }] },
    { name: 'approve', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'spender', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [{ name: '', type: 'bool' }] },
    { name: 'allowance', type: 'function', stateMutability: 'view', inputs: [{ name: 'owner', type: 'address' }, { name: 'spender', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
    { name: 'mint', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'to', type: 'address' }, { name: 'amount', type: 'uint256' }], outputs: [] },
];

// ZZNFT Upgradeable ABI
export const ZZNFTABI: Abi = [
    { name: 'name', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'string' }] },
    { name: 'symbol', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'string' }] },
    { name: 'balanceOf', type: 'function', stateMutability: 'view', inputs: [{ name: 'owner', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
    { name: 'ownerOf', type: 'function', stateMutability: 'view', inputs: [{ name: 'tokenId', type: 'uint256' }], outputs: [{ name: '', type: 'address' }] },
    { name: 'approve', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'to', type: 'address' }, { name: 'tokenId', type: 'uint256' }], outputs: [] },
    { name: 'setApprovalForAll', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'operator', type: 'address' }, { name: 'approved', type: 'bool' }], outputs: [] },
    { name: 'isApprovedForAll', type: 'function', stateMutability: 'view', inputs: [{ name: 'owner', type: 'address' }, { name: 'operator', type: 'address' }], outputs: [{ name: '', type: 'bool' }] },
    { name: 'mint', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'to', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
    { name: 'getCurrentTokenId', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
];

// NFT Market V2 ABI
export const NFTMarketABI: Abi = [
    { name: 'version', type: 'function', stateMutability: 'pure', inputs: [], outputs: [{ name: '', type: 'string' }] },
    { name: 'nextListingId', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'uint256' }] },
    { name: 'getListing', type: 'function', stateMutability: 'view', inputs: [{ name: 'listingId', type: 'uint256' }], outputs: [{ name: '', type: 'tuple', components: [{ name: 'seller', type: 'address' }, { name: 'active', type: 'bool' }, { name: 'nft', type: 'address' }, { name: 'tokenId', type: 'uint256' }, { name: 'payToken', type: 'address' }, { name: 'price', type: 'uint256' }] }] },
    { name: 'isSignatureListing', type: 'function', stateMutability: 'view', inputs: [{ name: 'listingId', type: 'uint256' }], outputs: [{ name: '', type: 'bool' }] },
    { name: 'list', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'nft', type: 'address' }, { name: 'tokenId', type: 'uint256' }, { name: 'payToken', type: 'address' }, { name: 'price', type: 'uint256' }], outputs: [{ name: 'listingId', type: 'uint256' }] },
    { name: 'buyNFT', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'listingId', type: 'uint256' }, { name: 'payAmount', type: 'uint256' }], outputs: [] },
    { name: 'cancelListing', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'listingId', type: 'uint256' }], outputs: [] },
    { name: 'listWithSignature', type: 'function', stateMutability: 'nonpayable', inputs: [{ name: 'nftContract', type: 'address' }, { name: 'tokenId', type: 'uint256' }, { name: 'payToken', type: 'address' }, { name: 'price', type: 'uint256' }, { name: 'deadline', type: 'uint256' }, { name: 'v', type: 'uint8' }, { name: 'r', type: 'bytes32' }, { name: 's', type: 'bytes32' }], outputs: [{ name: 'listingId', type: 'uint256' }] },
    { name: 'getSellerNonce', type: 'function', stateMutability: 'view', inputs: [{ name: 'seller', type: 'address' }], outputs: [{ name: '', type: 'uint256' }] },
    { name: 'getDomainSeparator', type: 'function', stateMutability: 'view', inputs: [], outputs: [{ name: '', type: 'bytes32' }] },
];

// Contract Addresses (update after deployment)
// export const CONTRACT_ADDRESSES = {
//     TOKEN: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512' as `0x${string}`,
//     NFT: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9' as `0x${string}`,
//     MARKET: '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707' as `0x${string}`,
// };

export const CONTRACT_ADDRESSES = {
    TOKEN: '0xddb24aaa31476a0886a1d5e4bc67371271f9e3ba' as `0x${string}`,
    NFT: '0x0e13e82fed033e04b8e5ae4e2856c73dc02960d0' as `0x${string}`,
    MARKET: '0x3241c027b1072a79dbe9c79966098077aeabc002' as `0x${string}`,
};

// EIP-712 types for signature listing
export const LISTING_PERMIT_TYPES = {
    ListingPermit: [
        { name: 'nftContract', type: 'address' },
        { name: 'tokenId', type: 'uint256' },
        { name: 'payToken', type: 'address' },
        { name: 'price', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
    ],
} as const;
