// 数据库类型定义
export interface Transfer {
    chain_id: number;
    token: string;
    tx_hash: string;
    log_index: number;
    block_number: number;
    block_hash: string;
    from_address: string;
    to_address: string;
    value: string;
    timestamp: number;
    created_at: number;
}
