'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { CONTRACTS, MARKET_ABI, TOKEN_ABI } from '@/config/contracts';

/**
 * PermitBuy Component
 * 白名单用户使用此组件携带签名购买 NFT
 */
export default function PermitBuy() {
    const { address } = useAccount();
    const [listingId, setListingId] = useState('');
    const [deadline, setDeadline] = useState('');
    const [v, setV] = useState('');
    const [r, setR] = useState('');
    const [s, setS] = useState('');

    // 读取 listing 信息
    const { data: listing } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'getListing',
        args: listingId ? [BigInt(listingId)] : undefined,
    });

    // 读取用户的 token 授权额度
    const { data: allowance, refetch: refetchAllowance } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'allowance',
        args: address ? [address, CONTRACTS.MARKET_ADDRESS as `0x${string}`] : undefined,
    });

    // approve 交易
    const {
        data: approveHash,
        writeContract: approveToken,
        isPending: isApprovePending,
    } = useWriteContract();

    const { isLoading: isApproveConfirming, isSuccess: isApproveSuccess } = useWaitForTransactionReceipt({
        hash: approveHash,
    });

    // 授权成功后刷新 allowance
    useEffect(() => {
        if (isApproveSuccess) {
            refetchAllowance();
        }
    }, [isApproveSuccess, refetchAllowance]);

    // permitBuy 交易
    const {
        data: buyHash,
        writeContract: permitBuy,
        isPending: isBuyPending,
    } = useWriteContract();

    const { isLoading: isBuyConfirming } = useWaitForTransactionReceipt({
        hash: buyHash,
    });

    const price = listing ? (listing as { price: bigint }).price : BigInt(0);
    const isActive = listing ? (listing as { active: boolean }).active : false;

    // 只有在有效 listing 且有 allowance 数据时才检查是否需要授权
    const currentAllowance = allowance as bigint | undefined;
    const needsApproval = isActive && price > BigInt(0) && (currentAllowance === undefined || currentAllowance < price);

    // 检查所有表单字段是否已填写
    const hasAllFields = listingId && deadline && v && r && s;

    const handleApprove = async () => {
        if (!price) return;

        try {
            await approveToken({
                address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                abi: TOKEN_ABI,
                functionName: 'approve',
                args: [CONTRACTS.MARKET_ADDRESS as `0x${string}`, price],
            });
        } catch (error) {
            console.error('Approve failed:', error);
        }
    };

    const handlePermitBuy = async () => {
        if (!listingId || !deadline || !v || !r || !s) return;

        try {
            await permitBuy({
                address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                abi: MARKET_ABI,
                functionName: 'permitBuy',
                args: [
                    BigInt(listingId),
                    BigInt(deadline),
                    parseInt(v),
                    r as `0x${string}`,
                    s as `0x${string}`,
                ],
            });
        } catch (error) {
            console.error('PermitBuy failed:', error);
        }
    };

    // 计算按钮是否应该禁用
    const isButtonDisabled = !address || !hasAllFields || !isActive || needsApproval || isBuyPending || isBuyConfirming;

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">🛍️ 白名单购买 (PermitBuy)</h3>
                <span className="badge badge-primary">需要签名</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                白名单用户输入项目方提供的签名参数，验证通过后可购买 NFT。
            </p>

            <div className="space-y-4">
                {/* Listing ID */}
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        Listing ID
                    </label>
                    <input
                        type="number"
                        className="input-field"
                        placeholder="0"
                        value={listingId}
                        onChange={(e) => setListingId(e.target.value)}
                    />
                </div>

                {/* Listing Info */}
                {listing && isActive && (
                    <div className="p-3 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.1)' }}>
                        <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                            <div>Token ID: {(listing as { tokenId: bigint }).tokenId.toString()}</div>
                            <div>价格: {(Number(price) / 1e18).toFixed(4)} ZZ</div>
                            <div>卖家: {(listing as { seller: string }).seller.slice(0, 8)}...</div>
                            <div>授权额度: {currentAllowance !== undefined ? (Number(currentAllowance) / 1e18).toFixed(4) : '加载中...'} ZZ</div>
                        </div>
                    </div>
                )}

                {listingId && !isActive && listing && (
                    <div className="p-3 rounded-lg" style={{ background: 'rgba(239, 68, 68, 0.1)' }}>
                        <div className="text-sm" style={{ color: 'var(--error)' }}>
                            ⚠ Listing #{listingId} 已售出或不存在
                        </div>
                    </div>
                )}

                {/* Signature Parameters */}
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        Deadline (Unix时间戳)
                    </label>
                    <input
                        type="text"
                        className="input-field"
                        placeholder="1640000000"
                        value={deadline}
                        onChange={(e) => setDeadline(e.target.value)}
                    />
                </div>

                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        v (签名参数)
                    </label>
                    <input
                        type="number"
                        className="input-field"
                        placeholder="27 or 28"
                        value={v}
                        onChange={(e) => setV(e.target.value)}
                    />
                </div>

                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        r (签名参数)
                    </label>
                    <input
                        type="text"
                        className="input-field"
                        placeholder="0x..."
                        value={r}
                        onChange={(e) => setR(e.target.value)}
                    />
                </div>

                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        s (签名参数)
                    </label>
                    <input
                        type="text"
                        className="input-field"
                        placeholder="0x..."
                        value={s}
                        onChange={(e) => setS(e.target.value)}
                    />
                </div>

                {/* Action Buttons */}
                <div className="space-y-3">
                    {needsApproval && (
                        <button
                            className="btn-secondary w-full"
                            onClick={handleApprove}
                            disabled={isApprovePending || isApproveConfirming}
                        >
                            {isApprovePending || isApproveConfirming ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="spinner"></div>
                                    授权中...
                                </span>
                            ) : (
                                `🔓 授权 ${(Number(price) / 1e18).toFixed(2)} ZZ 代币`
                            )}
                        </button>
                    )}

                    <button
                        className="btn-primary w-full"
                        onClick={handlePermitBuy}
                        disabled={isButtonDisabled}
                    >
                        {isBuyPending || isBuyConfirming ? (
                            <span className="flex items-center justify-center gap-2">
                                <div className="spinner"></div>
                                购买中...
                            </span>
                        ) : (
                            '🛒 Permit Buy'
                        )}
                    </button>
                </div>

                {/* Transaction Status */}
                {buyHash && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ PermitBuy tx: {buyHash.slice(0, 10)}...{buyHash.slice(-8)}
                    </div>
                )}

                {/* Info */}
                <div className="text-sm p-4 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.05)', color: 'var(--text-secondary)' }}>
                    <strong>流程：</strong>
                    <ol className="mt-2 space-y-1 ml-4 list-decimal">
                        <li>获取项目方提供的签名参数 (v, r, s, deadline)</li>
                        <li>输入 Listing ID 和签名参数</li>
                        <li>如需要，先点击「授权代币」按钮</li>
                        <li>点击 Permit Buy 完成购买</li>
                    </ol>
                </div>
            </div>
        </div>
    );
}
