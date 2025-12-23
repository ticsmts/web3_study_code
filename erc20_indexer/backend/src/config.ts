// 环境变量配置
export const config = {
    // RPC URLs
    anvilRpcUrl: process.env.ANVIL_RPC_URL || 'http://127.0.0.1:8545',
    sepoliaRpcUrl: process.env.SEPOLIA_RPC_URL || '',

    // Token addresses
    anvilTokenAddress: process.env.ANVIL_TOKEN_ADDRESS || '0x5fbdb2315678afecb367f032d93f642f64180aa3',
    sepoliaTokenAddress: process.env.SEPOLIA_TOKEN_ADDRESS || '',

    // Chain IDs
    anvilChainId: 31337,
    sepoliaChainId: 11155111,

    // API设置
    apiPort: parseInt(process.env.API_PORT || '3001'),

    // 数据库路径
    dbPath: process.env.DB_PATH || 'transfers.db',

    // 索引设置
    indexFromBlock: BigInt(process.env.INDEX_FROM_BLOCK || '0'),
    batchSize: 1000, // 每次获取日志的区块数量
};
