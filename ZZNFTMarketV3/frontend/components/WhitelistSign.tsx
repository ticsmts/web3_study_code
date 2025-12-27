'use client';

import { useState } from 'react';
import { useAccount, useReadContract, useSignTypedData } from 'wagmi';
import { CONTRACTS, MARKET_ABI } from '@/config/contracts';

/**
 * WhitelistSign Component
 * 项目方使用此组件为白名单用户生成签名
 */
export default function WhitelistSign() {
    const { address, chain } = useAccount();
    const [buyerAddress, setBuyerAddress] = useState('');
    const [listingId, setListingId] = useState('');
    const [signature, setSignature] = useState<{
        v: number;
        r: `0x${string}`;
        s: `0x${string}`;
        deadline: bigint;
    } | null>(null);

    // 读取项目方地址
    const { data: signer } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'signer',
    });

    // 读取买家的nonce
    const { data: buyerNonce } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'getNonce',
        args: buyerAddress ? [buyerAddress as `0x${string}`] : undefined,
    });

    // 签名
    const { signTypedData, isPending: isSignPending } = useSignTypedData();

    const isSigner = address && signer && address.toLowerCase() === signer.toLowerCase();

    const handleSign = async () => {
        if (!buyerAddress || !listingId || !chain || buyerNonce === undefined) return;

        const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour

        try {
            signTypedData(
                {
                    domain: {
                        name: 'ZZNFTMarketV3',
                        version: '1',
                        chainId: chain.id,
                        verifyingContract: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                    },
                    types: {
                        WhitelistPermit: [
                            { name: 'buyer', type: 'address' },
                            { name: 'listingId', type: 'uint256' },
                            { name: 'nonce', type: 'uint256' },
                            { name: 'deadline', type: 'uint256' },
                        ],
                    },
                    primaryType: 'WhitelistPermit',
                    message: {
                        buyer: buyerAddress as `0x${string}`,
                        listingId: BigInt(listingId),
                        nonce: buyerNonce as bigint,
                        deadline,
                    },
                },
                {
                    onSuccess: (sig) => {
                        const r = `0x${sig.slice(2, 66)}` as `0x${string}`;
                        const s = `0x${sig.slice(66, 130)}` as `0x${string}`;
                        const v = parseInt(sig.slice(130, 132), 16);
                        setSignature({ v, r, s, deadline });
                    },
                }
            );
        } catch (error) {
            console.error('Sign failed:', error);
        }
    };

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">🔐 项目方: 白名单签名</h3>
                {isSigner ? (
                    <span className="badge badge-success">✓ Authorized Signer</span>
                ) : (
                    <span className="badge badge-warning">⚠ Not Signer</span>
                )}
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                项目方为指定买家和 Listing 生成白名单授权签名。买家可使用此签名调用 permitBuy 购买 NFT。
            </p>

            <div className="space-y-4">
                {/* Buyer Address */}
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        买家地址
                    </label>
                    <input
                        type="text"
                        className="input-field"
                        placeholder="0x..."
                        value={buyerAddress}
                        onChange={(e) => setBuyerAddress(e.target.value)}
                    />
                </div>

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

                {/* Nonce Info */}
                {buyerNonce !== undefined && (
                    <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>
                        买家当前 Nonce: {buyerNonce.toString()}
                    </div>
                )}

                {/* Sign Button */}
                <button
                    className="btn-primary w-full"
                    onClick={handleSign}
                    disabled={!isSigner || !buyerAddress || !listingId || isSignPending}
                >
                    {isSignPending ? (
                        <span className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            签名中...
                        </span>
                    ) : (
                        '🔏 生成白名单签名'
                    )}
                </button>

                {/* Signature Display */}
                {signature && (
                    <div className="p-4 rounded-lg border" style={{
                        background: 'rgba(16, 185, 129, 0.1)',
                        borderColor: 'rgba(16, 185, 129, 0.3)'
                    }}>
                        <div className="flex items-center gap-2 mb-3">
                            <span className="text-xl">✅</span>
                            <span className="font-semibold" style={{ color: 'var(--success)' }}>
                                签名生成成功
                            </span>
                        </div>
                        <div className="text-sm space-y-2 font-mono" style={{ color: 'var(--text-secondary)' }}>
                            <div><strong>v:</strong> {signature.v}</div>
                            <div><strong>r:</strong> {signature.r}</div>
                            <div><strong>s:</strong> {signature.s}</div>
                            <div><strong>deadline:</strong> {signature.deadline.toString()}</div>
                            <div><strong>过期时间:</strong> {new Date(Number(signature.deadline) * 1000).toLocaleString()}</div>
                        </div>
                        <p className="mt-3 text-xs" style={{ color: 'var(--text-secondary)' }}>
                            请将以上信息发送给白名单买家，买家使用这些参数调用 permitBuy。
                        </p>
                    </div>
                )}
            </div>
        </div>
    );
}
