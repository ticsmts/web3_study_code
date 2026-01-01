'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { parseEther, isAddress } from 'viem';
import { CONTRACTS, NFT_ABI, TOKEN_ABI } from '@/config/contracts';

// 添加缺少的 ABI
const EXTENDED_NFT_ABI = [
    ...NFT_ABI,
    {
        inputs: [
            { name: 'to', type: 'address' },
        ],
        name: 'mint',
        outputs: [{ name: '', type: 'uint256' }],
        stateMutability: 'nonpayable',
        type: 'function',
    },
    {
        inputs: [],
        name: 'owner',
        outputs: [{ name: '', type: 'address' }],
        stateMutability: 'view',
        type: 'function',
    },
] as const;

const EXTENDED_TOKEN_ABI = [
    ...TOKEN_ABI,
    {
        inputs: [
            { name: 'to', type: 'address' },
            { name: 'amount', type: 'uint256' },
        ],
        name: 'transfer',
        outputs: [{ name: '', type: 'bool' }],
        stateMutability: 'nonpayable',
        type: 'function',
    },
] as const;

/**
 * AdminTools Component
 * 管理员工具：Mint NFT 和转账 Token
 */
export default function AdminTools() {
    const { address } = useAccount();

    // Mint NFT 状态
    const [mintTo, setMintTo] = useState('');
    const [mintTokenId, setMintTokenId] = useState('');

    // Transfer Token 状态
    const [transferTo, setTransferTo] = useState('');
    const [transferAmount, setTransferAmount] = useState('');

    // 读取 NFT owner
    const { data: nftOwner } = useReadContract({
        address: CONTRACTS.NFT_ADDRESS as `0x${string}`,
        abi: EXTENDED_NFT_ABI,
        functionName: 'owner',
    });

    // 读取 Token 余额
    const { data: tokenBalance } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'balanceOf',
        args: address ? [address] : undefined,
    });

    const isNFTOwner = address && nftOwner && address.toLowerCase() === (nftOwner as string).toLowerCase();
    const tokenBalanceFormatted = tokenBalance ? Number(tokenBalance) / 1e18 : 0;

    // Mint NFT 交易
    const {
        data: mintHash,
        writeContract: mintNFT,
        isPending: isMintPending,
        error: mintError,
    } = useWriteContract();

    const { isLoading: isMintConfirming, isSuccess: isMintSuccess, isError: isMintError } = useWaitForTransactionReceipt({
        hash: mintHash,
    });

    // Transfer Token 交易
    const {
        data: transferHash,
        writeContract: transferToken,
        isPending: isTransferPending,
        error: transferError,
    } = useWriteContract();

    const { isLoading: isTransferConfirming, isSuccess: isTransferSuccess, isError: isTransferError } = useWaitForTransactionReceipt({
        hash: transferHash,
    });

    // Mint NFT
    const handleMint = async () => {
        if (!mintTo || !isAddress(mintTo)) return;

        try {
            if (mintTokenId) {
                // 使用 mintTo 指定 tokenId
                await mintNFT({
                    address: CONTRACTS.NFT_ADDRESS as `0x${string}`,
                    abi: NFT_ABI,
                    functionName: 'mintTo',
                    args: [mintTo as `0x${string}`, BigInt(mintTokenId)],
                });
            } else {
                // 使用 mint 自动 tokenId
                await mintNFT({
                    address: CONTRACTS.NFT_ADDRESS as `0x${string}`,
                    abi: EXTENDED_NFT_ABI,
                    functionName: 'mint',
                    args: [mintTo as `0x${string}`],
                });
            }
        } catch (error) {
            console.error('Mint failed:', error);
        }
    };

    // Transfer Token
    const handleTransfer = async () => {
        if (!transferTo || !isAddress(transferTo) || !transferAmount) return;

        try {
            await transferToken({
                address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                abi: EXTENDED_TOKEN_ABI,
                functionName: 'transfer',
                args: [transferTo as `0x${string}`, parseEther(transferAmount)],
            });
        } catch (error) {
            console.error('Transfer failed:', error);
        }
    };

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">🛠️ 管理员工具</h3>
                <span className="badge badge-warning">测试用</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                用于测试的管理员功能：铸造 NFT 和转账 Token
            </p>

            <div className="space-y-6">
                {/* Mint NFT Section */}
                <div className="p-4 rounded-lg" style={{ background: 'rgba(139, 92, 246, 0.1)' }}>
                    <h4 className="font-semibold mb-3" style={{ color: 'var(--accent-secondary)' }}>
                        🎨 铸造 NFT
                    </h4>

                    {!isNFTOwner && (
                        <div className="text-sm mb-3 p-2 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                            ⚠️ 只有 NFT Owner 可以铸造
                        </div>
                    )}

                    <div className="space-y-3">
                        <div>
                            <label className="block text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>
                                接收地址
                            </label>
                            <input
                                type="text"
                                className="input-field text-sm"
                                placeholder="0x..."
                                value={mintTo}
                                onChange={(e) => setMintTo(e.target.value)}
                            />
                        </div>
                        <div>
                            <label className="block text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>
                                Token ID (可选，留空自动分配)
                            </label>
                            <input
                                type="number"
                                className="input-field text-sm"
                                placeholder="自动"
                                value={mintTokenId}
                                onChange={(e) => setMintTokenId(e.target.value)}
                            />
                        </div>
                        <button
                            className="btn-secondary w-full"
                            onClick={handleMint}
                            disabled={!isNFTOwner || !mintTo || !isAddress(mintTo) || isMintPending || isMintConfirming}
                        >
                            {isMintPending || isMintConfirming ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="spinner"></div>
                                    铸造中...
                                </span>
                            ) : (
                                '🎨 铸造 NFT'
                            )}
                        </button>

                        {isMintSuccess && (
                            <div className="text-xs p-2 rounded" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                                ✓ 铸造成功!
                            </div>
                        )}
                        {(isMintError || mintError) && (
                            <div className="text-xs p-2 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                                ✗ {mintError?.message?.slice(0, 50) || '铸造失败'}
                            </div>
                        )}
                    </div>
                </div>

                {/* Transfer Token Section */}
                <div className="p-4 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.1)' }}>
                    <h4 className="font-semibold mb-3" style={{ color: 'var(--accent-primary)' }}>
                        💰 转账 ZZ Token
                    </h4>

                    <div className="text-xs mb-3" style={{ color: 'var(--text-secondary)' }}>
                        你的余额: <span className="font-semibold">{tokenBalanceFormatted.toFixed(2)} ZZ</span>
                    </div>

                    <div className="space-y-3">
                        <div>
                            <label className="block text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>
                                接收地址
                            </label>
                            <input
                                type="text"
                                className="input-field text-sm"
                                placeholder="0x..."
                                value={transferTo}
                                onChange={(e) => setTransferTo(e.target.value)}
                            />
                        </div>
                        <div>
                            <label className="block text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>
                                数量 (ZZ)
                            </label>
                            <input
                                type="number"
                                className="input-field text-sm"
                                placeholder="1000"
                                value={transferAmount}
                                onChange={(e) => setTransferAmount(e.target.value)}
                            />
                        </div>
                        <button
                            className="btn-primary w-full"
                            onClick={handleTransfer}
                            disabled={!transferTo || !isAddress(transferTo) || !transferAmount || isTransferPending || isTransferConfirming}
                        >
                            {isTransferPending || isTransferConfirming ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="spinner"></div>
                                    转账中...
                                </span>
                            ) : (
                                '💸 转账 Token'
                            )}
                        </button>

                        {isTransferSuccess && (
                            <div className="text-xs p-2 rounded" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                                ✓ 转账成功!
                            </div>
                        )}
                        {(isTransferError || transferError) && (
                            <div className="text-xs p-2 rounded" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                                ✗ {transferError?.message?.slice(0, 50) || '转账失败'}
                            </div>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
