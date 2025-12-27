'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract, useSignTypedData } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { CONTRACTS, TOKEN_ABI, BANK_ABI } from '@/config/contracts';

export default function V3Permit() {
    const { address, chain } = useAccount();
    const [amount, setAmount] = useState('');
    const [signature, setSignature] = useState<{ v: number; r: `0x${string}`; s: `0x${string}`; deadline: bigint } | null>(null);

    // 读取 nonce
    const { data: nonce } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'nonces',
        args: address ? [address] : undefined,
    });

    // 读取 token name
    const { data: tokenName } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'name',
    });

    // 签名
    const { signTypedData, isPending: isSignPending } = useSignTypedData();

    // PermitDeposit 交易
    const {
        data: hash,
        writeContract: permitDeposit,
        isPending: isTransactionPending,
    } = useWriteContract();

    const { isLoading: isConfirming } = useWaitForTransactionReceipt({
        hash,
        onReplaced: (replacement) => {
            console.log('PermitDeposit confirmed:', replacement);
            setAmount('');
            setSignature(null);
        },
    });

    const handleSign = async () => {
        if (!amount || parseFloat(amount) <= 0 || !address || !chain || nonce === undefined) return;

        const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now
        const amountBigInt = parseEther(amount);

        try {
            signTypedData(
                {
                    domain: {
                        name: (tokenName as string) || 'ZZ Token V2',
                        version: '1',
                        chainId: chain.id,
                        verifyingContract: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                    },
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
                    message: {
                        owner: address,
                        spender: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                        value: amountBigInt,
                        nonce: nonce as bigint,
                        deadline,
                    },
                },
                {
                    onSuccess: (sig) => {
                        // 解析签名
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

    const handlePermitDeposit = async () => {
        if (!signature || !amount) return;

        try {
            await permitDeposit({
                address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                abi: BANK_ABI,
                functionName: 'permitDeposit',
                args: [parseEther(amount), signature.deadline, signature.v, signature.r, signature.s],
            });
        } catch (error) {
            console.error('PermitDeposit failed:', error);
        }
    };

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">V3: Permit + PermitDeposit</h3>
                <span className="badge badge-primary">1 Tx (Best!)</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                使用 EIP-2612 Permit 签名授权（离线），然后一笔链上交易完成存款。节省 gas 并提升用户体验。
            </p>

            <div className="space-y-4">
                {/* Amount input */}
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        存款数量
                    </label>
                    <input
                        type="number"
                        className="input-field"
                        placeholder="0.0"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        disabled={!!signature}
                    />
                </div>

                {/* Signature status */}
                {signature && (
                    <div className="p-4 rounded-lg border" style={{
                        background: 'rgba(139, 92, 246, 0.1)',
                        borderColor: 'rgba(139, 92, 246, 0.3)'
                    }}>
                        <div className="flex items-center gap-2 mb-2">
                            <span className="text-xl">✍️</span>
                            <span className="font-semibold" style={{ color: 'var(--accent-secondary)' }}>
                                签名已生成
                            </span>
                        </div>
                        <div className="text-sm space-y-1" style={{ color: 'var(--text-secondary)' }}>
                            <div>v: {signature.v}</div>
                            <div>r: {signature.r.slice(0, 20)}...</div>
                            <div>s: {signature.s.slice(0, 20)}...</div>
                            <div>deadline: {new Date(Number(signature.deadline) * 1000).toLocaleString()}</div>
                        </div>
                    </div>
                )}

                {/* Action buttons */}
                <div className="flex gap-3">
                    {!signature ? (
                        <button
                            className="btn-primary flex-1"
                            onClick={handleSign}
                            disabled={!address || !amount || parseFloat(amount) <= 0 || isSignPending}
                        >
                            {isSignPending ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="spinner"></div>
                                    Signing...
                                </span>
                            ) : (
                                '🖊️ Sign Permit (Off-chain)'
                            )}
                        </button>
                    ) : (
                        <>
                            <button
                                className="btn-secondary"
                                onClick={() => {
                                    setSignature(null);
                                    setAmount('');
                                }}
                            >
                                重新签名
                            </button>
                            <button
                                className="btn-primary flex-1"
                                onClick={handlePermitDeposit}
                                disabled={!address || isTransactionPending || isConfirming}
                            >
                                {isTransactionPending || isConfirming ? (
                                    <span className="flex items-center justify-center gap-2">
                                        <div className="spinner"></div>
                                        Depositing...
                                    </span>
                                ) : (
                                    '⛓️ Submit Transaction (On-chain)'
                                )}
                            </button>
                        </>
                    )}
                </div>

                {/* Transaction status */}
                {hash && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ PermitDeposit tx: {hash.slice(0, 10)}...{hash.slice(-8)}
                    </div>
                )}

                {/* Explanation */}
                <div className="text-sm p-4 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.05)', color: 'var(--text-secondary)' }}>
                    <strong>优势：</strong>
                    <ul className="mt-2 space-y-1 ml-4">
                        <li>• 只需一笔链上交易（节省 gas）</li>
                        <li>• 离线签名，无需等待区块确认</li>
                        <li>• 用户体验更好</li>
                        <li>• 符合 EIP-2612 标准</li>
                    </ul>
                </div>
            </div>
        </div>
    );
}
