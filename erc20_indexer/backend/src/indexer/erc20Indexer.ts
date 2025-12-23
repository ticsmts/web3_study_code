import { createPublicClient, http, parseAbiItem, type Log, type Address, type Hash } from 'viem';
import { localhost, sepolia } from 'viem/chains';
import { TransferDatabase } from '../db/database';
import { Transfer } from '../db/schema';
import { config } from '../config';

export class ERC20Indexer {
    private db: TransferDatabase;
    private anvilClient;
    private sepoliaClient;

    constructor(database: TransferDatabase) {
        this.db = database;

        // 创建anvil客户端
        this.anvilClient = createPublicClient({
            chain: localhost,
            transport: http(config.anvilRpcUrl),
        });

        // 创建sepolia客户端
        if (config.sepoliaRpcUrl) {
            this.sepoliaClient = createPublicClient({
                chain: sepolia,
                transport: http(config.sepoliaRpcUrl),
            });
        }
    }

    // 索引历史转账记录
    async indexHistoricalTransfers(chainId: number): Promise<void> {
        const client = chainId === config.anvilChainId ? this.anvilClient : this.sepoliaClient;
        const tokenAddress = (chainId === config.anvilChainId
            ? config.anvilTokenAddress
            : config.sepoliaTokenAddress) as Address;

        if (!client) {
            console.error(`❌ No client configured for chain ${chainId}`);
            return;
        }

        console.log(`🔍 Indexing historical transfers for chain ${chainId}, token ${tokenAddress}`);

        // 获取最后索引的区块
        const lastIndexedBlock = this.db.getLastIndexedBlock(chainId, tokenAddress);
        const fromBlock = lastIndexedBlock > 0 ? BigInt(lastIndexedBlock + 1) : config.indexFromBlock;

        // 获取当前区块
        const currentBlock = await client.getBlockNumber();
        console.log(`📊 Indexing from block ${fromBlock} to ${currentBlock}`);

        // 分批获取日志(避免RPC限制)
        let processedBlocks = fromBlock;
        while (processedBlocks <= currentBlock) {
            const toBlock = processedBlocks + BigInt(config.batchSize) > currentBlock
                ? currentBlock
                : processedBlocks + BigInt(config.batchSize);

            try {
                const logs = await client.getLogs({
                    address: tokenAddress,
                    event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
                    fromBlock: processedBlocks,
                    toBlock: toBlock,
                });

                console.log(`📦 Found ${logs.length} transfer events in blocks ${processedBlocks} - ${toBlock}`);

                // 处理日志并存入数据库
                if (logs.length > 0) {
                    await this.processLogs(logs, chainId, tokenAddress);
                }

                processedBlocks = toBlock + 1n;
            } catch (error) {
                console.error(`❌ Error fetching logs from ${processedBlocks} to ${toBlock}:`, error);
                break;
            }
        }

        console.log(`✅ Indexing complete for chain ${chainId}`);
    }

    // 处理日志并存入数据库
    private async processLogs(logs: Log[], chainId: number, tokenAddress: Address): Promise<void> {
        const transfers: Transfer[] = [];

        for (const log of logs) {
            try {
                // 获取区块信息以获取timestamp
                const client = chainId === config.anvilChainId ? this.anvilClient : this.sepoliaClient;
                const block = await client!.getBlock({ blockHash: log.blockHash as Hash });

                const transfer: Transfer = {
                    chain_id: chainId,
                    token: tokenAddress,
                    tx_hash: log.transactionHash as string,
                    log_index: Number(log.logIndex),
                    block_number: Number(log.blockNumber),
                    block_hash: log.blockHash as string,
                    from_address: (log.topics[1] as string).replace('0x000000000000000000000000', '0x'),
                    to_address: (log.topics[2] as string).replace('0x000000000000000000000000', '0x'),
                    value: BigInt(log.data).toString(),
                    timestamp: Number(block.timestamp),
                    created_at: Date.now(),
                };

                transfers.push(transfer);
            } catch (error) {
                console.error(`❌ Error processing log:`, error);
            }
        }

        // 批量插入数据库
        if (transfers.length > 0) {
            this.db.insertTransfers(transfers);
            console.log(`💾 Saved ${transfers.length} transfers to database`);
        }
    }

    // 监听新的转账事件(实时索引)
    async watchNewTransfers(chainId: number): Promise<void> {
        const client = chainId === config.anvilChainId ? this.anvilClient : this.sepoliaClient;
        const tokenAddress = (chainId === config.anvilChainId
            ? config.anvilTokenAddress
            : config.sepoliaTokenAddress) as Address;

        if (!client) {
            console.error(`❌ No client configured for chain ${chainId}`);
            return;
        }

        console.log(`👀 Watching new transfers for chain ${chainId}, token ${tokenAddress}`);

        client.watchEvent({
            address: tokenAddress,
            event: parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)'),
            onLogs: async (logs) => {
                console.log(`🆕 Received ${logs.length} new transfer event(s)`);
                await this.processLogs(logs, chainId, tokenAddress);
            },
        });
    }
}
