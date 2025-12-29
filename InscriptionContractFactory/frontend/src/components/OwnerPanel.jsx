import { useState, useEffect } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther } from 'viem';
import { FACTORY_ADDRESS, FACTORY_ABI } from '../contracts';

export function OwnerPanel({ inscriptions }) {
    const { address, isConnected } = useAccount();

    // 获取工厂 Owner
    const { data: owner } = useReadContract({
        address: FACTORY_ADDRESS,
        abi: FACTORY_ABI,
        functionName: 'owner',
    });

    // 获取累计费用
    const { data: totalFees, refetch: refetchFees } = useReadContract({
        address: FACTORY_ADDRESS,
        abi: FACTORY_ABI,
        functionName: 'totalFees',
    });

    // 提取费用
    const { writeContract, data: hash, isPending, error, reset } = useWriteContract();
    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

    const isOwner = address && owner && address.toLowerCase() === owner.toLowerCase();

    // 筛选当前用户创建的铭文
    const myInscriptions = inscriptions?.filter(
        (ins) => ins.creator?.toLowerCase() === address?.toLowerCase()
    ) || [];

    // 计算我的铭文的总收益 (仅显示，无法分别提取)
    const myTotalRevenue = myInscriptions.reduce((acc, ins) => {
        const mintCount = ins.totalMinted / ins.perMint;
        return acc + (ins.price * mintCount);
    }, 0n);

    const handleWithdraw = () => {
        writeContract({
            address: FACTORY_ADDRESS,
            abi: FACTORY_ABI,
            functionName: 'withdrawFees',
        });
    };

    useEffect(() => {
        if (isSuccess) {
            setTimeout(() => {
                refetchFees();
                reset();
            }, 2000);
        }
    }, [isSuccess, refetchFees, reset]);

    if (!isConnected) {
        return null;
    }

    return (
        <div className="card owner-panel">
            <h2>👤 我的铭文</h2>

            {myInscriptions.length > 0 ? (
                <div className="my-inscriptions">
                    <div className="my-inscriptions-header">
                        <span>共创建 <strong>{myInscriptions.length}</strong> 个铭文</span>
                        {myTotalRevenue > 0n && (
                            <span className="revenue-info">
                                预计收益: <strong>{formatEther(myTotalRevenue)} ETH</strong>
                            </span>
                        )}
                    </div>
                    <div className="my-inscriptions-list">
                        {myInscriptions.map((ins) => (
                            <div key={ins.address} className="my-inscription-item">
                                <span className="my-inscription-symbol">{ins.symbol}</span>
                                <span className="my-inscription-stats">
                                    {formatEther(ins.totalMinted)} / {formatEther(ins.totalSupply)}
                                </span>
                                {ins.price > 0n && (
                                    <span className="my-inscription-price">
                                        {formatEther(ins.price)} ETH
                                    </span>
                                )}
                            </div>
                        ))}
                    </div>
                </div>
            ) : (
                <p className="empty-state-small">您还没有创建任何铭文</p>
            )}

            {/* Owner 专属: 提取所有费用 */}
            {isOwner && (
                <div className="owner-section">
                    <div className="owner-header">
                        <span className="owner-badge">🔑 Owner</span>
                    </div>
                    <div className="owner-stats">
                        <div className="stat-row">
                            <span>合约累计收益</span>
                            <strong>{totalFees ? formatEther(totalFees) : '0'} ETH</strong>
                        </div>
                    </div>

                    {error && (
                        <div className="error-message">
                            ❌ {error.shortMessage || '提取失败'}
                        </div>
                    )}

                    {isSuccess && (
                        <div className="success-message">
                            ✅ 提取成功！
                        </div>
                    )}

                    <button
                        onClick={handleWithdraw}
                        className="btn btn-withdraw"
                        disabled={!totalFees || totalFees === 0n || isPending || isConfirming}
                    >
                        {isPending ? '确认中...' : isConfirming ? '提取中...' : '提取收益'}
                    </button>
                </div>
            )}
        </div>
    );
}
