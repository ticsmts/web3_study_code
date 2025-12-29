import { useState, useEffect, useRef, useCallback } from 'react';
import { useReadContract, useAccount, usePublicClient } from 'wagmi';
import { formatEther } from 'viem';
import { FACTORY_ADDRESS, FACTORY_ABI, TOKEN_ABI } from '../contracts';
import { MintButton } from './MintButton';

export function InscriptionList({ refreshTrigger, onInscriptionsLoaded }) {
    const { address } = useAccount();
    const publicClient = usePublicClient();
    const [inscriptions, setInscriptions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    const isFetchingRef = useRef(false);
    const lastCountRef = useRef(null);

    const { data: count, refetch: refetchCount, isLoading: countLoading } = useReadContract({
        address: FACTORY_ADDRESS,
        abi: FACTORY_ABI,
        functionName: 'getInscriptionsCount',
    });

    const fetchInscriptions = useCallback(async (forceCount) => {
        const targetCount = forceCount ?? count;

        if (!publicClient || targetCount === undefined) {
            return;
        }

        if (isFetchingRef.current) {
            return;
        }

        if (targetCount === lastCountRef.current && inscriptions.length > 0) {
            setLoading(false);
            return;
        }

        if (targetCount === 0n) {
            setInscriptions([]);
            setLoading(false);
            lastCountRef.current = targetCount;
            return;
        }

        try {
            isFetchingRef.current = true;
            setLoading(true);
            setError(null);

            const numCount = Number(targetCount);
            const results = [];

            for (let i = 0; i < numCount; i++) {
                try {
                    const tokenAddr = await publicClient.readContract({
                        address: FACTORY_ADDRESS,
                        abi: FACTORY_ABI,
                        functionName: 'allInscriptions',
                        args: [BigInt(i)],
                    });

                    const info = await publicClient.readContract({
                        address: FACTORY_ADDRESS,
                        abi: FACTORY_ABI,
                        functionName: 'getInscriptionInfo',
                        args: [tokenAddr],
                    });

                    // V2: 获取价格
                    let price = 0n;
                    try {
                        price = await publicClient.readContract({
                            address: FACTORY_ADDRESS,
                            abi: FACTORY_ABI,
                            functionName: 'getInscriptionPrice',
                            args: [tokenAddr],
                        });
                    } catch {
                        // V1 铭文没有价格
                    }

                    let userBalance = 0n;
                    if (address) {
                        try {
                            userBalance = await publicClient.readContract({
                                address: tokenAddr,
                                abi: TOKEN_ABI,
                                functionName: 'balanceOf',
                                args: [address],
                            });
                        } catch {
                            // Ignore balance errors
                        }
                    }

                    const [creator, symbol, totalSupply, perMint, totalMinted, remainingSupply] = info;
                    results.push({
                        address: tokenAddr,
                        creator,
                        symbol,
                        totalSupply,
                        perMint,
                        totalMinted,
                        remainingSupply,
                        userBalance,
                        price,
                    });
                } catch (e) {
                    console.warn(`Failed to fetch inscription ${i}:`, e);
                }
            }

            lastCountRef.current = targetCount;
            setInscriptions(results);
            setLoading(false);

            // 通知父组件
            if (onInscriptionsLoaded) {
                onInscriptionsLoaded(results);
            }
        } catch (e) {
            console.error('Failed to fetch inscriptions:', e);
            setError(e.message);
            setLoading(false);
        } finally {
            isFetchingRef.current = false;
        }
    }, [publicClient, address]);

    useEffect(() => {
        if (!countLoading && count !== undefined && publicClient) {
            fetchInscriptions(count);
        }
    }, [countLoading, count, publicClient]);

    useEffect(() => {
        if (refreshTrigger > 0) {
            lastCountRef.current = null;
            refetchCount();
        }
    }, [refreshTrigger, refetchCount]);

    const handleMinted = useCallback(() => {
        lastCountRef.current = null;
        refetchCount();
    }, [refetchCount]);

    const handleRetry = () => {
        lastCountRef.current = null;
        setError(null);
        refetchCount();
    };

    if (countLoading) {
        return (
            <div className="card">
                <h2>📜 铭文列表</h2>
                <p className="empty-state">加载中...</p>
            </div>
        );
    }

    if (error) {
        return (
            <div className="card">
                <h2>📜 铭文列表</h2>
                <p className="empty-state">加载失败: {error}</p>
                <button className="btn btn-primary" onClick={handleRetry}>
                    重试
                </button>
            </div>
        );
    }

    if (loading && inscriptions.length === 0) {
        return (
            <div className="card">
                <h2>📜 铭文列表</h2>
                <p className="empty-state">加载中...</p>
            </div>
        );
    }

    if (!count || count === 0n || inscriptions.length === 0) {
        return (
            <div className="card">
                <h2>📜 铭文列表</h2>
                <p className="empty-state">暂无铭文，请先部署一个铭文</p>
            </div>
        );
    }

    return (
        <div className="card">
            <h2>📜 铭文列表 ({inscriptions.length})</h2>
            <div className="inscription-grid">
                {inscriptions.map((item) => (
                    <div key={item.address} className="inscription-item">
                        <div className="inscription-header">
                            <span className="inscription-symbol">{item.symbol}</span>
                            <span className="inscription-address">
                                {item.address.slice(0, 6)}...{item.address.slice(-4)}
                            </span>
                        </div>

                        <div className="inscription-stats">
                            <div className="stat">
                                <span className="stat-label">最大供应</span>
                                <span className="stat-value">{formatEther(item.totalSupply)}</span>
                            </div>
                            <div className="stat">
                                <span className="stat-label">每次铸造</span>
                                <span className="stat-value">{formatEther(item.perMint)}</span>
                            </div>
                            <div className="stat">
                                <span className="stat-label">已铸造</span>
                                <span className="stat-value">{formatEther(item.totalMinted)}</span>
                            </div>
                            <div className="stat">
                                <span className="stat-label">剩余</span>
                                <span className="stat-value">{formatEther(item.remainingSupply)}</span>
                            </div>
                        </div>

                        {/* V2: 显示价格 */}
                        {item.price > 0n && (
                            <div className="inscription-price">
                                💰 铸造价格: <strong>{formatEther(item.price)} ETH</strong>
                            </div>
                        )}
                        {item.price === 0n && (
                            <div className="inscription-price free">
                                🆓 免费铸造
                            </div>
                        )}

                        <div className="inscription-progress">
                            <div
                                className="progress-bar"
                                style={{
                                    width: `${Number(item.totalMinted) * 100 / Number(item.totalSupply)}%`
                                }}
                            />
                        </div>

                        {address && (
                            <div className="user-balance">
                                我的持有: <strong>{formatEther(item.userBalance)}</strong> {item.symbol}
                            </div>
                        )}

                        <MintButton
                            tokenAddress={item.address}
                            price={item.price}
                            disabled={item.remainingSupply === 0n}
                            onMinted={handleMinted}
                        />
                    </div>
                ))}
            </div>
        </div>
    );
}
