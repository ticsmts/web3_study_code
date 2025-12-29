// Contract configuration for Inscription Factory V2
// 升级到 V2 - 支持价格参数和付费 mint

export const FACTORY_ADDRESS = "0x50180de3322F3309Db32f19D5537C3698EEE9078";
export const FACTORY_VERSION = "v2";

// InscriptionFactoryV2 ABI
export const FACTORY_ABI = [
    {
        "inputs": [],
        "stateMutability": "nonpayable",
        "type": "constructor"
    },
    {
        "inputs": [],
        "name": "InscriptionNotFound",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InvalidParameters",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InsufficientPayment",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "WithdrawFailed",
        "type": "error"
    },
    {
        "anonymous": false,
        "inputs": [
            { "indexed": true, "internalType": "address", "name": "token", "type": "address" },
            { "indexed": true, "internalType": "address", "name": "creator", "type": "address" },
            { "indexed": false, "internalType": "string", "name": "symbol", "type": "string" },
            { "indexed": false, "internalType": "uint256", "name": "totalSupply", "type": "uint256" },
            { "indexed": false, "internalType": "uint256", "name": "perMint", "type": "uint256" }
        ],
        "name": "InscriptionDeployed",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            { "indexed": true, "internalType": "address", "name": "token", "type": "address" },
            { "indexed": true, "internalType": "address", "name": "creator", "type": "address" },
            { "indexed": false, "internalType": "string", "name": "symbol", "type": "string" },
            { "indexed": false, "internalType": "uint256", "name": "totalSupply", "type": "uint256" },
            { "indexed": false, "internalType": "uint256", "name": "perMint", "type": "uint256" },
            { "indexed": false, "internalType": "uint256", "name": "price", "type": "uint256" }
        ],
        "name": "InscriptionDeployedV2",
        "type": "event"
    },
    {
        "anonymous": false,
        "inputs": [
            { "indexed": true, "internalType": "address", "name": "token", "type": "address" },
            { "indexed": true, "internalType": "address", "name": "to", "type": "address" },
            { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
        ],
        "name": "InscriptionMinted",
        "type": "event"
    },
    {
        "inputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "name": "allInscriptions",
        "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            { "internalType": "string", "name": "symbol", "type": "string" },
            { "internalType": "uint256", "name": "totalSupply", "type": "uint256" },
            { "internalType": "uint256", "name": "perMint", "type": "uint256" }
        ],
        "name": "deployInscription",
        "outputs": [{ "internalType": "address", "name": "tokenAddress", "type": "address" }],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            { "internalType": "string", "name": "symbol", "type": "string" },
            { "internalType": "uint256", "name": "totalSupply", "type": "uint256" },
            { "internalType": "uint256", "name": "perMint", "type": "uint256" },
            { "internalType": "uint256", "name": "price", "type": "uint256" }
        ],
        "name": "deployInscription",
        "outputs": [{ "internalType": "address", "name": "tokenAddress", "type": "address" }],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{ "internalType": "address", "name": "tokenAddr", "type": "address" }],
        "name": "getInscriptionInfo",
        "outputs": [
            { "internalType": "address", "name": "creator", "type": "address" },
            { "internalType": "string", "name": "symbol", "type": "string" },
            { "internalType": "uint256", "name": "totalSupply", "type": "uint256" },
            { "internalType": "uint256", "name": "perMint", "type": "uint256" },
            { "internalType": "uint256", "name": "totalMinted", "type": "uint256" },
            { "internalType": "uint256", "name": "remainingSupply", "type": "uint256" }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{ "internalType": "address", "name": "tokenAddr", "type": "address" }],
        "name": "getInscriptionPrice",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getInscriptionsCount",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{ "internalType": "address", "name": "tokenAddr", "type": "address" }],
        "name": "mintInscription",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "owner",
        "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "tokenImplementation",
        "outputs": [{ "internalType": "address", "name": "", "type": "address" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "totalFees",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "version",
        "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
        "stateMutability": "pure",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "withdrawFees",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
];

// InscriptionToken ABI (for reading token details)
export const TOKEN_ABI = [
    {
        "inputs": [{ "internalType": "address", "name": "account", "type": "address" }],
        "name": "balanceOf",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "name",
        "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "symbol",
        "outputs": [{ "internalType": "string", "name": "", "type": "string" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "maxSupply",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "perMint",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "totalMinted",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "remainingSupply",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "totalSupply",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "decimals",
        "outputs": [{ "internalType": "uint8", "name": "", "type": "uint8" }],
        "stateMutability": "view",
        "type": "function"
    }
];
