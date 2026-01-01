'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract, useSignTypedData } from 'wagmi';
import { encodeFunctionData, keccak256, parseEther } from 'viem';
import { CONTRACTS, MARKET_ABI, TOKEN_ABI } from '@/config/contracts';

interface Listing {
    seller: string;
    active: boolean;
    nft: string;
    tokenId: bigint;
    payToken: string;
    price: bigint;
}

/**
 * MerkleClaimNFT Component
 * 白名单用户使用 Merkle Proof + Permit 通过 Multicall 购买 NFT
 */
export default function MerkleClaimNFT() {
    const { address } = useAccount();
    const [listingId, setListingId] = useState('');
    const [merkleProof, setMerkleProof] = useState('');
    const [isProcessing, setIsProcessing] = useState(false);

    // 获取 listing 信息
    const { data: listing } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'getListing',
        args: listingId ? [BigInt(listingId)] : undefined,
    });

    // 获取 token nonce
    const { data: nonce } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'nonces',
        args: address ? [address] : undefined,
    });

    // 获取 token domain separator
    const { data: domainSeparator } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'DOMAIN_SEPARATOR',
    });

    // EIP-712 签名
    const { signTypedDataAsync } = useSignTypedData();

    // multicall 交易
    const {
        data: multicallHash,
        writeContract: executeMulticall,
        isPending: isMulticallPending,
        error: multicallError,
    } = useWriteContract();

    const { isLoading: isMulticallConfirming, isSuccess: isMulticallSuccess, isError: isMulticallError } = useWaitForTransactionReceipt({
        hash: multicallHash,
    });

    const l = listing as Listing | undefined;
    const discountedPrice = l ? l.price / 2n : 0n;

    // 解析 Merkle Proof
    const parseProof = (proofStr: string): `0x${string}`[] => {
        if (!proofStr.trim()) return [];
        try {
            const parsed = JSON.parse(proofStr);
            if (Array.isArray(parsed)) {
                return parsed.map(p => p as `0x${string}`);
            }
        } catch {
            // 尝试用逗号分隔
            return proofStr.split(',').map(p => p.trim() as `0x${string}`).filter(p => p.startsWith('0x'));
        }
        return [];
    };

    const handleMulticallPurchase = async () => {
        if (!address || !listingId || !l || !l.active) return;
        setIsProcessing(true);

        try {
            const proof = parseProof(merkleProof);
            const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1小时后过期

            // 1. 签名 permit
            const signature = await signTypedDataAsync({
                types: {
                    Permit: [
                        { name: 'owner', type: 'address' },
                        { name: 'spender', type: 'address' },
                        { name: 'value', type: 'uint256' },
                        { name: 'nonce', type: 'uint256' },
                        { name: 'deadline', type: 'uint256' },
                    ],
                },
                primaryType: 'Permit',
                domain: {
                    name: 'ZZTOKEN',
                    version: '1',
                    chainId: 31337,
                    verifyingContract: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                },
                message: {
                    owner: address,
                    spender: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                    value: discountedPrice,
                    nonce: nonce || 0n,
                    deadline: deadline,
                },
            });

            // 解析签名
            const r = signature.slice(0, 66) as `0x${string}`;
            const s = ('0x' + signature.slice(66, 130)) as `0x${string}`;
            const v = parseInt(signature.slice(130, 132), 16);

            // 2. 编码 permitPrePay 调用数据
            const permitData = encodeFunctionData({
                abi: MARKET_ABI,
                functionName: 'permitPrePay',
                args: [
                    CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                    address,
                    CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                    discountedPrice,
                    deadline,
                    v,
                    r,
                    s,
                ],
            });

            // 3. 编码 claimNFT 调用数据
            const claimData = encodeFunctionData({
                abi: MARKET_ABI,
                functionName: 'claimNFT',
                args: [BigInt(listingId), proof],
            });

            // 4. 执行 multicall
            await executeMulticall({
                address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                abi: MARKET_ABI,
                functionName: 'multicall',
                args: [[permitData, claimData]],
            });
        } catch (error) {
            console.error('Multicall purchase failed:', error);
        } finally {
            setIsProcessing(false);
        }
    };

    const canPurchase = address && listingId && l && l.active && l.seller.toLowerCase() !== address.toLowerCase();

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">🎁 白名单购买</h3>
                <span className="badge badge-success">50% 折扣</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                白名单用户使用 <strong>Merkle Proof</strong> + <strong>Permit</strong> 通过 <strong>Multicall</strong> 一次性完成授权和购买。
            </p>

            <div className="space-y-4">
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

                {l && (
                    <div className="p-3 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.1)' }}>
                        <div className="text-sm">
                            <div className="flex justify-between mb-1">
                                <span style={{ color: 'var(--text-secondary)' }}>Token ID:</span>
                                <span className="font-semibold">#{l.tokenId.toString()}</span>
                            </div>
                            <div className="flex justify-between mb-1">
                                <span style={{ color: 'var(--text-secondary)' }}>原价:</span>
                                <span className="line-through">{(Number(l.price) / 1e18).toFixed(2)} ZZ</span>
                            </div>
                            <div className="flex justify-between">
                                <span style={{ color: 'var(--text-secondary)' }}>折扣价:</span>
                                <span className="font-bold" style={{ color: 'var(--success)' }}>
                                    {(Number(discountedPrice) / 1e18).toFixed(2)} ZZ
                                </span>
                            </div>
                            <div className="flex justify-between mt-2">
                                <span style={{ color: 'var(--text-secondary)' }}>状态:</span>
                                <span style={{ color: l.active ? 'var(--success)' : 'var(--error)' }}>
                                    {l.active ? '✓ 可购买' : '✗ 已售出'}
                                </span>
                            </div>
                        </div>
                    </div>
                )}

                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        Merkle Proof (JSON 数组或逗号分隔)
                    </label>
                    <textarea
                        className="input-field"
                        placeholder='["0x...", "0x..."] 或留空（单地址白名单）'
                        value={merkleProof}
                        onChange={(e) => setMerkleProof(e.target.value)}
                        rows={3}
                    />
                    <div className="text-xs mt-1" style={{ color: 'var(--text-secondary)' }}>
                        如果白名单只有一个地址，可留空
                    </div>
                </div>

                <button
                    className="btn-primary w-full"
                    onClick={handleMulticallPurchase}
                    disabled={!canPurchase || isProcessing || isMulticallPending || isMulticallConfirming}
                >
                    {isProcessing || isMulticallPending || isMulticallConfirming ? (
                        <span className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            {isProcessing ? '签名中...' : '购买中...'}
                        </span>
                    ) : (
                        '🚀 Multicall 购买 (Permit + Claim)'
                    )}
                </button>

                {/* 状态提示 */}
                {isMulticallSuccess && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ 购买成功! tx: {multicallHash?.slice(0, 10)}...{multicallHash?.slice(-8)}
                    </div>
                )}
                {(isMulticallError || multicallError) && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                        ✗ 购买失败: {multicallError?.message?.slice(0, 80) || '交易失败'}
                    </div>
                )}

                {/* 流程说明 */}
                <div className="text-xs p-3 rounded-lg" style={{ background: 'rgba(251, 146, 60, 0.1)', color: '#fb923c' }}>
                    <strong>Multicall 流程:</strong>
                    <ol className="list-decimal ml-4 mt-1 space-y-1">
                        <li>签名 EIP-2612 Permit（授权 Token）</li>
                        <li>执行 permitPrePay（链上 permit 调用）</li>
                        <li>执行 claimNFT（验证白名单 + 转移 NFT）</li>
                    </ol>
                </div>
            </div>
        </div>
    );
}
