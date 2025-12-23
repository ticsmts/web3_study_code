import { http, createConfig } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import { injected } from 'wagmi/connectors'

// 手动定义Anvil链,确保ID为31337(不使用wagmi的localhost,因为它默认是1337)
const anvil = {
    id: 31337,
    name: 'Anvil',
    nativeCurrency: {
        name: 'Ether',
        symbol: 'ETH',
        decimals: 18
    },
    rpcUrls: {
        default: { http: ['http://127.0.0.1:8545'] },
    },
}

export const config = createConfig({
    chains: [anvil, sepolia],
    connectors: [injected()],
    transports: {
        [anvil.id]: http('http://127.0.0.1:8545'),
        [sepolia.id]: http(),
    },
})

export const CHAINS = {
    31337: {
        name: 'Anvil Local',
        tokenAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    },
    11155111: {
        name: 'Sepolia Testnet',
        tokenAddress: '0x5C4829789Cb5d86b15034D7E8C8ddDcb45890Cff',
    },
}

export const API_URL = 'http://localhost:3001'
