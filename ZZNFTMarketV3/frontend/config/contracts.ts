export const CONTRACTS = {
    // 部署后更新这些地址
    TOKEN_ADDRESS: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    NFT_ADDRESS: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    MARKET_ADDRESS: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
} as const;

// ZZToken ABI (ERC20)
export const TOKEN_ABI = [
    {
        inputs: [{ name: 'account', type: 'address' }],
        name: 'balanceOf',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
        ],
        name: 'allowance',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            { name: 'spender', type: 'address' },
            { name: 'amount', type: 'uint256' },
        ],
        name: 'approve',
        outputs: [{ name: '', type: 'bool' }],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [],
        name: 'name',
        outputs: [{ name: '', type: 'string' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'symbol',
        outputs: [{ name: '', type: 'string' }],
        stateMutability: 'view',
        type: 'function',
    },
] as const;

// ZZNFT ABI (ERC721)
export const NFT_ABI = [
    {
        inputs: [{ name: 'tokenId', type: 'uint256' }],
        name: 'ownerOf',
        outputs: [{ name: '', type: 'address' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [{ name: 'owner', type: 'address' }],
        name: 'balanceOf',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            { name: 'to', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
        ],
        name: 'approve',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [{ name: 'tokenId', type: 'uint256' }],
        name: 'tokenURI',
        outputs: [{ name: '', type: 'string' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            { name: 'to', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
        ],
        name: 'mint',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
] as const;

// ZZNFTMarketV3 ABI
export const MARKET_ABI = [
    // List
    {
        inputs: [
            { name: 'nft', type: 'address' },
            { name: 'tokenId', type: 'uint256' },
            { name: 'payToken', type: 'address' },
            { name: 'price', type: 'uint256' },
        ],
        name: 'list',
        outputs: [{ name: 'listingId', type: 'uint256' }],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    // buyNFT
    {
        inputs: [
            { name: 'listingId', type: 'uint256' },
            { name: 'payAmount', type: 'uint256' },
        ],
        name: 'buyNFT',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    // permitBuy
    {
        inputs: [
            { name: 'listingId', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
            { name: 'v', type: 'uint8' },
            { name: 'r', type: 'bytes32' },
            { name: 's', type: 'bytes32' },
        ],
        name: 'permitBuy',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    // getListing
    {
        inputs: [{ name: 'listingId', type: 'uint256' }],
        name: 'getListing',
        outputs: [{
            components: [
                { name: 'seller', type: 'address' },
                { name: 'nft', type: 'address' },
                { name: 'tokenId', type: 'uint256' },
                { name: 'payToken', type: 'address' },
                { name: 'price', type: 'uint256' },
                { name: 'active', type: 'bool' },
            ],
            name: '',
            type: 'tuple',
        }],
        stateMutability: 'view',
        type: 'function',
    },
    // getNonce
    {
        inputs: [{ name: 'user', type: 'address' }],
        name: 'getNonce',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    // getDomainSeparator
    {
        inputs: [],
        name: 'getDomainSeparator',
        outputs: [{ name: '', type: 'bytes32' }],
        stateMutability: 'view',
        type: 'function',
    },
    // nextListingId
    {
        inputs: [],
        name: 'nextListingId',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    // signer
    {
        inputs: [],
        name: 'signer',
        outputs: [{ name: '', type: 'address' }],
        stateMutability: 'view',
        type: 'function',
    },
    // Events
    {
        anonymous: false,
        inputs: [
            { indexed: true, name: 'listingId', type: 'uint256' },
            { indexed: true, name: 'seller', type: 'address' },
            { indexed: true, name: 'nft', type: 'address' },
            { indexed: false, name: 'tokenId', type: 'uint256' },
            { indexed: false, name: 'payToken', type: 'address' },
            { indexed: false, name: 'price', type: 'uint256' },
        ],
        name: 'Listed',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            { indexed: true, name: 'listingId', type: 'uint256' },
            { indexed: true, name: 'buyer', type: 'address' },
            { indexed: true, name: 'seller', type: 'address' },
            { indexed: false, name: 'nft', type: 'address' },
            { indexed: false, name: 'tokenId', type: 'uint256' },
            { indexed: false, name: 'payToken', type: 'address' },
            { indexed: false, name: 'price', type: 'uint256' },
        ],
        name: 'Bought',
        type: 'event',
    },
    {
        anonymous: false,
        inputs: [
            { indexed: true, name: 'listingId', type: 'uint256' },
            { indexed: true, name: 'buyer', type: 'address' },
            { indexed: true, name: 'seller', type: 'address' },
            { indexed: false, name: 'nft', type: 'address' },
            { indexed: false, name: 'tokenId', type: 'uint256' },
            { indexed: false, name: 'payToken', type: 'address' },
            { indexed: false, name: 'price', type: 'uint256' },
        ],
        name: 'PermitBought',
        type: 'event',
    },
] as const;
