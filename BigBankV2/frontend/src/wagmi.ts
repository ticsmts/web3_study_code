import { createConfig, http } from 'wagmi';
import { localhost } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

// 本地 Anvil 链配置
const anvilChain = {
    ...localhost,
    id: 31337,
    name: 'Anvil Local',
    nativeCurrency: {
        name: 'Ether',
        symbol: 'ETH',
        decimals: 18,
    },
    rpcUrls: {
        default: { http: ['http://127.0.0.1:8545'] },
    },
} as const;

export const config = createConfig({
    chains: [anvilChain],
    connectors: [
        injected({
            target: 'metaMask',
        }),
    ],
    transports: {
        [anvilChain.id]: http('http://127.0.0.1:8545'),
    },
});

// BigBankV2 合约 ABI
export const BigBankV2ABI = [
    {
        type: 'function',
        name: 'deposit',
        inputs: [],
        outputs: [],
        stateMutability: 'payable',
    },
    {
        type: 'function',
        name: 'getTopDepositors',
        inputs: [],
        outputs: [
            { name: 'users', type: 'address[]' },
            { name: 'amounts', type: 'uint256[]' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        name: 'getBalance',
        inputs: [{ name: 'user', type: 'address' }],
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        name: 'getTotalBalance',
        inputs: [],
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        name: 'MIN_DEPOSIT',
        inputs: [],
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'view',
    },
    {
        type: 'event',
        name: 'Deposit',
        inputs: [
            { name: 'user', type: 'address', indexed: true },
            { name: 'amount', type: 'uint256', indexed: false },
            { name: 'newBalance', type: 'uint256', indexed: false },
        ],
    },
] as const;

// 部署后更新此地址
export const CONTRACT_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as const;
