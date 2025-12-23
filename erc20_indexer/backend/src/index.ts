import { config as dotenvConfig } from 'dotenv';
import { TransferDatabase } from './db/database';
import { ERC20Indexer } from './indexer/erc20Indexer';
import { startServer } from './api/server';
import { config } from './config';

// 加载环境变量
dotenvConfig();

async function main() {
    console.log('🚀 Starting ERC20 Transfer Indexer...\n');

    // 初始化数据库
    const db = new TransferDatabase(config.dbPath);
    console.log('');

    // 创建索引器
    const indexer = new ERC20Indexer(db);

    // 索引anvil链的历史数据
    console.log('📚 Indexing Anvil chain historical transfers...');
    await indexer.indexHistoricalTransfers(config.anvilChainId);
    console.log('');

    // 开始监听新转账(可选)
    // indexer.watchNewTransfers(config.anvilChainId);

    // 如果配置了Sepolia,也索引Sepolia
    if (config.sepoliaRpcUrl && config.sepoliaTokenAddress) {
        console.log('📚 Indexing Sepolia chain historical transfers...');
        await indexer.indexHistoricalTransfers(config.sepoliaChainId);
        console.log('');
    }

    // 启动API服务器
    startServer(db);

    // 统计信息
    const totalCount = db.getTotalCount();
    console.log(`\n📊 Total indexed transfers: ${totalCount}`);
}

main().catch((error) => {
    console.error('❌ Fatal error:', error);
    process.exit(1);
});
