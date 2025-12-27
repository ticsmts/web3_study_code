'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { parseEther } from 'viem';
import { CONTRACTS, MARKET_ABI, NFT_ABI } from '@/config/contracts';

/**
 * ListNFT Component
 * 卖家使用此组件上架 NFT
 */
export default function ListNFT() {
    const { address } = useAccount();
    const [tokenId, setTokenId] = useState('');
    const [price, setPrice] = useState('');

    // 检查 NFT 所有者
    const { data: nftOwner, isLoading: isOwnerLoading, refetch: refetchOwner } = useReadContract({
        address: CONTRACTS.NFT_ADDRESS as `0x${string}`,
        abi: NFT_ABI,
        functionName: 'ownerOf',
        args: tokenId ? [BigInt(tokenId)] : undefined,
    });

    const isOwner = nftOwner && address && nftOwner.toString().toLowerCase() === address.toLowerCase();

    // NFT approve 交易
    const {
        data: approveHash,
        writeContract: approveNFT,
        isPending: isApprovePending,
        error: approveError,
    } = useWriteContract();

    const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess, isError: isApproveError } = useWaitForTransactionReceipt({
        hash: approveHash,
    });

    // list 交易
    const {
        data: listHash,
        writeContract: listNFT,
        isPending: isListPending,
        error: listError,
    } = useWriteContract();

    const { isLoading: isListConfirming, isSuccess: isListSuccess, isError: isListError } = useWaitForTransactionReceipt({
        hash: listHash,
    });

    // 上架成功后刷新 owner 信息
    useEffect(() => {
        if (isListSuccess) {
            refetchOwner();
        }
    }, [isListSuccess, refetchOwner]);

    const handleApprove = async () => {
        if (!tokenId || !address || !isOwner) return;

        try {
            await approveNFT({
                address: CONTRACTS.NFT_ADDRESS as `0x${string}`,
                abi: NFT_ABI,
                functionName: 'approve',
                args: [CONTRACTS.MARKET_ADDRESS as `0x${string}`, BigInt(tokenId)],
            });
        } catch (error) {
            console.error('Approve failed:', error);
        }
    };

    const handleList = async () => {
        if (!tokenId || !price || !isOwner) return;

        try {
            await listNFT({
                address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                abi: MARKET_ABI,
                functionName: 'list',
                args: [
                    CONTRACTS.NFT_ADDRESS as `0x${string}`,
                    BigInt(tokenId),
                    CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                    parseEther(price),
                ],
            });
        } catch (error) {
            console.error('List failed:', error);
        }
    };

    // 判断当前 tokenId 是否可以操作
    const canOperate = tokenId && !isOwnerLoading && isOwner;

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">📤 上架 NFT</h3>
                <span className="badge badge-primary">卖家</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                将你的 NFT 上架到市场，设置价格后等待买家购买。
            </p>

            <div className="space-y-4">
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        NFT Token ID
                    </label>
                    <input
                        type="number"
                        className="input-field"
                        placeholder="1"
                        value={tokenId}
                        onChange={(e) => setTokenId(e.target.value)}
                    />
                </div>

                {tokenId && (
                    <div className="text-sm" style={{ color: isOwnerLoading ? 'var(--text-secondary)' : (isOwner ? 'var(--success)' : 'var(--error)') }}>
                        {isOwnerLoading ? '加载中...' : (isOwner ? '✓ 你拥有此 NFT' : `⚠ 此 NFT 归属: ${nftOwner?.toString().slice(0, 10)}...`)}
                    </div>
                )}

                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        价格 (ZZ Token)
                    </label>
                    <input
                        type="number"
                        className="input-field"
                        placeholder="100"
                        value={price}
                        onChange={(e) => setPrice(e.target.value)}
                    />
                </div>

                <div className="flex gap-3">
                    <button
                        className="btn-secondary flex-1"
                        onClick={handleApprove}
                        disabled={!canOperate || isApprovePending || isApproveConfirming}
                    >
                        {isApprovePending || isApproveConfirming ? (
                            <span className="flex items-center justify-center gap-2">
                                <div className="spinner"></div>
                                授权中...
                            </span>
                        ) : (
                            '🔓 授权 NFT'
                        )}
                    </button>

                    <button
                        className="btn-primary flex-1"
                        onClick={handleList}
                        disabled={!canOperate || !price || isListPending || isListConfirming}
                    >
                        {isListPending || isListConfirming ? (
                            <span className="flex items-center justify-center gap-2">
                                <div className="spinner"></div>
                                上架中...
                            </span>
                        ) : (
                            '📤 上架'
                        )}
                    </button>
                </div>

                {/* 授权状态 */}
                {isApproveSuccess && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ NFT 授权成功!
                    </div>
                )}
                {(isApproveError || approveError) && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                        ✗ 授权失败: {approveError?.message?.slice(0, 50) || '交易失败'}
                    </div>
                )}

                {/* 上架状态 */}
                {isListSuccess && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ 上架成功! tx: {listHash?.slice(0, 10)}...{listHash?.slice(-8)}
                    </div>
                )}
                {(isListError || listError) && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                        ✗ 上架失败: {listError?.message?.slice(0, 50) || '交易失败'}
                    </div>
                )}
            </div>
        </div>
    );
}
