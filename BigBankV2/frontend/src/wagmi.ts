import { createConfig, http } from 'wagmi';
import { sepolia } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

// Sepolia 测试网配置
export const config = createConfig({
    chains: [sepolia],
    connectors: [
        injected({
            target: 'metaMask',
        }),
    ],
    transports: {
        [sepolia.id]: http(),
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

// Sepolia 测试网部署地址
export const CONTRACT_ADDRESS = '0xa805FD120EB3D78A17a6AAcFD920294C3B3959B8' as const;
