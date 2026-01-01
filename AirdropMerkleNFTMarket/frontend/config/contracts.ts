export const CONTRACTS = {
    // 部署后更新这些地址
    TOKEN_ADDRESS: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    NFT_ADDRESS: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
    MARKET_ADDRESS: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
} as const;

// ZZToken ABI (ERC20 + EIP-2612 Permit)
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
    {
        inputs: [{ name: 'owner', type: 'address' }],
        name: 'nonces',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [],
        name: 'DOMAIN_SEPARATOR',
        outputs: [{ name: '', type: 'bytes32' }],
        stateMutability: 'view',
        type: 'function',
    },
    {
        inputs: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
            { name: 'v', type: 'uint8' },
            { name: 'r', type: 'bytes32' },
            { name: 's', type: 'bytes32' },
        ],
        name: 'permit',
        outputs: [],
        stateMutability: 'nonpayable',
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
        name: 'mintTo',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
] as const;

// AirdropMerkleNFTMarket ABI
export const MARKET_ABI = [
    // list
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
    // permitPrePay
    {
        inputs: [
            { name: 'token', type: 'address' },
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
            { name: 'v', type: 'uint8' },
            { name: 'r', type: 'bytes32' },
            { name: 's', type: 'bytes32' },
        ],
        name: 'permitPrePay',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    // claimNFT
    {
        inputs: [
            { name: 'listingId', type: 'uint256' },
            { name: 'merkleProof', type: 'bytes32[]' },
        ],
        name: 'claimNFT',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    // multicall
    {
        inputs: [{ name: 'data', type: 'bytes[]' }],
        name: 'multicall',
        outputs: [{ name: 'results', type: 'bytes[]' }],
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
                { name: 'active', type: 'bool' },
                { name: 'nft', type: 'address' },
                { name: 'tokenId', type: 'uint256' },
                { name: 'payToken', type: 'address' },
                { name: 'price', type: 'uint256' },
            ],
            name: '',
            type: 'tuple',
        }],
        stateMutability: 'view',
        type: 'function',
    },
    // getDiscountedPrice
    {
        inputs: [{ name: 'listingId', type: 'uint256' }],
        name: 'getDiscountedPrice',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
        type: 'function',
    },
    // isWhitelisted
    {
        inputs: [
            { name: 'user', type: 'address' },
            { name: 'merkleProof', type: 'bytes32[]' },
        ],
        name: 'isWhitelisted',
        outputs: [{ name: '', type: 'bool' }],
        stateMutability: 'view',
        type: 'function',
    },
    // merkleRoot
    {
        inputs: [],
        name: 'merkleRoot',
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
    // admin
    {
        inputs: [],
        name: 'admin',
        outputs: [{ name: '', type: 'address' }],
        stateMutability: 'view',
        type: 'function',
    },
    // setMerkleRoot
    {
        inputs: [{ name: '_newRoot', type: 'bytes32' }],
        name: 'setMerkleRoot',
        outputs: [],
        stateMutability: 'nonpayable',
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
            { indexed: false, name: 'originalPrice', type: 'uint256' },
            { indexed: false, name: 'discountedPrice', type: 'uint256' },
        ],
        name: 'NFTClaimed',
        type: 'event',
    },
] as const;

// Merkle tree helper - 用于本地测试的白名单配置
export const WHITELIST_CONFIG = {
    // 测试用白名单地址 - 部署时更新
    addresses: [
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Anvil account 0
        '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', // Anvil account 1
    ],
};
