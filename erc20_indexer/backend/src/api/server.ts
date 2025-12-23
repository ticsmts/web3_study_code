import express, { Request, Response } from 'express';
import cors from 'cors';
import { TransferDatabase } from '../db/database';
import { config } from '../config';

export function createServer(db: TransferDatabase) {
    const app = express();

    // 中间件
    app.use(cors());
    app.use(express.json());

    // 健康检查
    app.get('/health', (req: Request, res: Response) => {
        res.json({ status: 'ok', timestamp: Date.now() });
    });

    // 获取某地址的转账记录
    app.get('/api/transfers/:address', (req: Request, res: Response) => {
        try {
            const { address } = req.params;
            const chainId = parseInt(req.query.chainId as string);
            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 50;

            // 验证参数
            if (!address || !chainId) {
                res.status(400).json({ error: 'address and chainId are required' });
                return;
            }

            // 查询数据库
            const transfers = db.getTransfersByAddress(address, chainId, page, limit);
            const total = db.getTotalCount(address, chainId);

            res.json({
                data: transfers,
                pagination: {
                    page,
                    limit,
                    total,
                    totalPages: Math.ceil(total / limit),
                },
            });
        } catch (error) {
            console.error('Error fetching transfers:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    // 获取统计信息
    app.get('/api/stats', (req: Request, res: Response) => {
        try {
            const chainId = req.query.chainId ? parseInt(req.query.chainId as string) : undefined;
            const total = db.getTotalCount();

            res.json({
                totalTransfers: total,
                chainId: chainId || 'all',
                timestamp: Date.now(),
            });
        } catch (error) {
            console.error('Error fetching stats:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    });

    return app;
}

export function startServer(db: TransferDatabase) {
    const app = createServer(db);

    app.listen(config.apiPort, () => {
        console.log(`🚀 API server running on http://localhost:${config.apiPort}`);
        console.log(`📍 Endpoints:`);
        console.log(`   GET /health`);
        console.log(`   GET /api/transfers/:address?chainId=<chainId>&page=<page>&limit=<limit>`);
        console.log(`   GET /api/stats`);
    });

    return app;
}
