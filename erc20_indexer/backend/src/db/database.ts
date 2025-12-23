import Database from 'better-sqlite3';
import path from 'path';
import { Transfer } from './schema';

export class TransferDatabase {
    private db: Database.Database;

    constructor(dbPath: string = 'transfers.db') {
        this.db = new Database(dbPath);
        this.initDatabase();
    }

    private initDatabase() {
        // 创建transfers表
        this.db.exec(`
      CREATE TABLE IF NOT EXISTS transfers (
        chain_id INTEGER NOT NULL,
        token TEXT NOT NULL,
        tx_hash TEXT NOT NULL,
        log_index INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        block_hash TEXT NOT NULL,
        from_address TEXT NOT NULL,
        to_address TEXT NOT NULL,
        value TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (chain_id, tx_hash, log_index)
      );
    `);

        // 创建索引加速查询
        this.db.exec(`
      CREATE INDEX IF NOT EXISTS idx_from ON transfers(from_address);
      CREATE INDEX IF NOT EXISTS idx_to ON transfers(to_address);
      CREATE INDEX IF NOT EXISTS idx_block ON transfers(block_number);
      CREATE INDEX IF NOT EXISTS idx_chain_token ON transfers(chain_id, token);
    `);

        console.log('✅ Database initialized');
    }

    // 插入或忽略转账记录(避免重复)
    insertTransfer(transfer: Transfer): void {
        const stmt = this.db.prepare(`
      INSERT OR IGNORE INTO transfers (
        chain_id, token, tx_hash, log_index, block_number, block_hash,
        from_address, to_address, value, timestamp, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

        stmt.run(
            transfer.chain_id,
            transfer.token.toLowerCase(),
            transfer.tx_hash,
            transfer.log_index,
            transfer.block_number,
            transfer.block_hash,
            transfer.from_address.toLowerCase(),
            transfer.to_address.toLowerCase(),
            transfer.value,
            transfer.timestamp,
            transfer.created_at
        );
    }

    // 批量插入transfers
    insertTransfers(transfers: Transfer[]): void {
        const stmt = this.db.prepare(`
      INSERT OR IGNORE INTO transfers (
        chain_id, token, tx_hash, log_index, block_number, block_hash,
        from_address, to_address, value, timestamp, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

        const insertMany = this.db.transaction((transfers: Transfer[]) => {
            for (const transfer of transfers) {
                stmt.run(
                    transfer.chain_id,
                    transfer.token.toLowerCase(),
                    transfer.tx_hash,
                    transfer.log_index,
                    transfer.block_number,
                    transfer.block_hash,
                    transfer.from_address.toLowerCase(),
                    transfer.to_address.toLowerCase(),
                    transfer.value,
                    transfer.timestamp,
                    transfer.created_at
                );
            }
        });

        insertMany(transfers);
    }

    // 查询某地址的转账记录(发送或接收)
    getTransfersByAddress(
        address: string,
        chainId: number,
        page: number = 1,
        limit: number = 50
    ): Transfer[] {
        const offset = (page - 1) * limit;
        const stmt = this.db.prepare(`
      SELECT * FROM transfers
      WHERE chain_id = ? AND (from_address = ? OR to_address = ?)
      ORDER BY block_number DESC, log_index DESC
      LIMIT ? OFFSET ?
    `);

        return stmt.all(chainId, address.toLowerCase(), address.toLowerCase(), limit, offset) as Transfer[];
    }

    // 获取总记录数
    getTotalCount(address?: string, chainId?: number): number {
        if (address && chainId) {
            const stmt = this.db.prepare(`
        SELECT COUNT(*) as count FROM transfers
        WHERE chain_id = ? AND (from_address = ? OR to_address = ?)
      `);
            const result = stmt.get(chainId, address.toLowerCase(), address.toLowerCase()) as { count: number };
            return result.count;
        } else {
            const stmt = this.db.prepare('SELECT COUNT(*) as count FROM transfers');
            const result = stmt.get() as { count: number };
            return result.count;
        }
    }

    // 获取最后索引的区块号
    getLastIndexedBlock(chainId: number, token: string): number {
        const stmt = this.db.prepare(`
      SELECT MAX(block_number) as max_block FROM transfers
      WHERE chain_id = ? AND token = ?
    `);
        const result = stmt.get(chainId, token.toLowerCase()) as { max_block: number | null };
        return result.max_block || 0;
    }

    close() {
        this.db.close();
    }
}
