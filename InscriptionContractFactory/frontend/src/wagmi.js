import { http, createConfig } from 'wagmi';
import { sepolia } from 'wagmi/chains';
import { injected } from 'wagmi/connectors';

export const config = createConfig({
    chains: [sepolia],
    connectors: [
        injected(),
    ],
    transports: {
        // 使用 Ankr 公共 RPC - 支持完整功能
        [sepolia.id]: http('https://api.zan.top/eth-sepolia'),
    },
});
