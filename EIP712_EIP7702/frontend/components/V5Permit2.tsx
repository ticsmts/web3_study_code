'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, usePublicClient, useSignTypedData } from 'wagmi';
import { parseEther, formatEther, maxUint256, type Hex } from 'viem';
import { CONTRACTS, TOKEN_ABI, BANK_ABI, PERMIT2_ABI } from '@/config/contracts';

// Permit2 EIP-712 Domain
const PERMIT2_DOMAIN = {
    name: 'Permit2',
    chainId: 31337, // Anvil local chain
    verifyingContract: CONTRACTS.PERMIT2_ADDRESS as `0x${string}`,
};

// Permit2 SignatureTransfer Types
const PERMIT_TRANSFER_FROM_TYPES = {
    PermitTransferFrom: [
        { name: 'permitted', type: 'TokenPermissions' },
        { name: 'spender', type: 'address' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
    ],
    TokenPermissions: [
        { name: 'token', type: 'address' },
        { name: 'amount', type: 'uint256' },
    ],
} as const;

export default function V5Permit2() {
    const { address, isConnected } = useAccount();
    const publicClient = usePublicClient();

    const [amount, setAmount] = useState('');
    const [status, setStatus] = useState<'idle' | 'checking' | 'approving' | 'signing' | 'depositing' | 'success' | 'error'>('idle');
    const [txHash, setTxHash] = useState<Hex | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [hasPermit2Approval, setHasPermit2Approval] = useState<boolean>(false);

    // Sign typed data for Permit2
    const { signTypedDataAsync } = useSignTypedData();

    // Approve token to Permit2
    const { writeContractAsync: approvePermit2 } = useWriteContract();

    // Deposit with Permit2
    const { writeContractAsync: depositWithPermit2, data: depositTxHash } = useWriteContract();

    // Wait for transaction
    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash: txHash as Hex | undefined,
    });

    // Check if token is approved to Permit2
    useEffect(() => {
        const checkApproval = async () => {
            if (!address || !publicClient) return;
            try {
                const allowance = await publicClient.readContract({
                    address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                    abi: TOKEN_ABI,
                    functionName: 'allowance',
                    args: [address, CONTRACTS.PERMIT2_ADDRESS as `0x${string}`],
                });
                setHasPermit2Approval((allowance as bigint) > 0n);
            } catch (e) {
                console.error('Failed to check Permit2 approval:', e);
            }
        };
        checkApproval();
    }, [address, publicClient, txHash]);

    // Find unused nonce from nonceBitmap
    const findUnusedNonce = async (): Promise<bigint> => {
        if (!publicClient || !address) return 0n;

        // Check word position 0
        const bitmap = await publicClient.readContract({
            address: CONTRACTS.PERMIT2_ADDRESS as `0x${string}`,
            abi: PERMIT2_ABI,
            functionName: 'nonceBitmap',
            args: [address, 0n],
        });

        // Find first unused bit
        const bitmapValue = bitmap as bigint;
        for (let i = 0n; i < 256n; i++) {
            if ((bitmapValue & (1n << i)) === 0n) {
                return i; // Return first unused nonce
            }
        }
        return 0n; // Fallback to 0
    };

    // Handle Permit2 approval
    const handleApprovePermit2 = async () => {
        if (!address) return;

        try {
            setStatus('approving');
            setError(null);

            const hash = await approvePermit2({
                address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                abi: TOKEN_ABI,
                functionName: 'approve',
                args: [CONTRACTS.PERMIT2_ADDRESS as `0x${string}`, maxUint256],
            });

            setTxHash(hash);
            console.log('[V5] Permit2 approval tx:', hash);

            // Wait for confirmation
            if (publicClient) {
                await publicClient.waitForTransactionReceipt({ hash });
                setHasPermit2Approval(true);
                setStatus('idle');
            }
        } catch (err: any) {
            console.error('[V5] Approval error:', err);
            setError(err.message?.slice(0, 100) || 'Approval failed');
            setStatus('error');
        }
    };

    // Handle Permit2 deposit
    const handlePermit2Deposit = async () => {
        if (!address || !amount || parseFloat(amount) <= 0 || !publicClient) {
            setError('请输入有效金额');
            return;
        }

        try {
            setStatus('signing');
            setError(null);
            setTxHash(null);

            const amountWei = parseEther(amount);
            const nonce = await findUnusedNonce();
            const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour

            console.log('[V5] Creating Permit2 signature...');
            console.log('[V5] Amount:', amountWei.toString());
            console.log('[V5] Nonce:', nonce.toString());
            console.log('[V5] Deadline:', deadline.toString());

            // Create permit message
            const permitMessage = {
                permitted: {
                    token: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                    amount: amountWei,
                },
                spender: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                nonce,
                deadline,
            };

            // Sign the permit using EIP-712
            const signature = await signTypedDataAsync({
                domain: PERMIT2_DOMAIN,
                types: PERMIT_TRANSFER_FROM_TYPES,
                primaryType: 'PermitTransferFrom',
                message: permitMessage,
            });

            console.log('[V5] Signature obtained:', signature.slice(0, 20) + '...');
            setStatus('depositing');

            // Call depositWithPermit2
            const hash = await depositWithPermit2({
                address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                abi: BANK_ABI,
                functionName: 'depositWithPermit2',
                args: [amountWei, nonce, deadline, signature],
            });

            console.log('[V5] Deposit tx:', hash);
            setTxHash(hash);

            // Wait for confirmation
            const receipt = await publicClient.waitForTransactionReceipt({ hash });
            console.log('[V5] Receipt:', receipt);

            if (receipt.status === 'reverted') {
                throw new Error('交易已回滚');
            }

            setStatus('success');
        } catch (err: any) {
            console.error('[V5] Error:', err);
            let errorMsg = err.message || '交易失败';
            if (errorMsg.includes('User rejected')) {
                errorMsg = '用户拒绝签名';
            }
            setError(errorMsg.slice(0, 150));
            setStatus('error');
        }
    };

    const getStatusDisplay = () => {
        switch (status) {
            case 'checking': return { text: '检查授权...', icon: '🔍' };
            case 'approving': return { text: '授权 Permit2...', icon: '✍️' };
            case 'signing': return { text: '签名中...', icon: '✍️' };
            case 'depositing': return { text: '存款中...', icon: '📤' };
            case 'success': return { text: '存款成功！', icon: '✅' };
            case 'error': return { text: '交易失败', icon: '❌' };
            default: return null;
        }
    };

    const statusDisplay = getStatusDisplay();
    const isProcessing = status === 'checking' || status === 'approving' || status === 'signing' || status === 'depositing';

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">V5: Permit2 签名存款</h3>
                <span className="badge badge-warning">1 Tx + Signature</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                使用 Uniswap <strong>Permit2</strong> 协议，一次性签名授权转账，
                无需每次 approve，适用于<strong>任何 ERC20</strong> 代币。
            </p>

            <div className="space-y-4">
                {/* Permit2 工作原理 */}
                <div className="p-3 rounded-lg border" style={{
                    background: 'rgba(234, 179, 8, 0.1)',
                    borderColor: 'rgba(234, 179, 8, 0.3)',
                }}>
                    <div className="text-sm" style={{ color: '#eab308' }}>
                        <strong>🔐 工作原理：</strong>
                        <ol className="mt-2 space-y-1 ml-4" style={{ color: 'var(--text-secondary)' }}>
                            <li>1. 首次使用：授权 Token 给 Permit2 合约</li>
                            <li>2. 签署 EIP-712 消息（离线签名）</li>
                            <li>3. Bank 合约调用 Permit2.permitTransferFrom</li>
                        </ol>
                    </div>
                </div>

                {/* 授权状态 */}
                {isConnected && (
                    <div className="p-3 rounded-lg" style={{
                        background: hasPermit2Approval
                            ? 'rgba(16, 185, 129, 0.1)'
                            : 'rgba(239, 68, 68, 0.1)',
                    }}>
                        <div className="flex items-center justify-between">
                            <div className="text-sm">
                                <span className="mr-2">{hasPermit2Approval ? '✅' : '❌'}</span>
                                Token → Permit2: {hasPermit2Approval ? '已授权' : '未授权'}
                            </div>
                            {!hasPermit2Approval && (
                                <button
                                    className="btn-secondary text-xs py-1 px-3"
                                    onClick={handleApprovePermit2}
                                    disabled={isProcessing}
                                >
                                    授权
                                </button>
                            )}
                        </div>
                    </div>
                )}

                {/* 存款输入 */}
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
                        disabled={isProcessing}
                    />
                </div>

                {/* 存款按钮 */}
                <button
                    className="btn-primary w-full"
                    onClick={handlePermit2Deposit}
                    disabled={!isConnected || !hasPermit2Approval || !amount || isProcessing}
                >
                    {isProcessing ? (
                        <div className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            <span>{statusDisplay?.text}</span>
                        </div>
                    ) : (
                        '🔐 Permit2 签名存款'
                    )}
                </button>

                {/* 状态显示 */}
                {statusDisplay && status !== 'idle' && (
                    <div className="p-3 rounded-lg" style={{
                        background: status === 'success' ? 'rgba(16, 185, 129, 0.1)' :
                            status === 'error' ? 'rgba(239, 68, 68, 0.1)' :
                                'rgba(234, 179, 8, 0.1)',
                        color: status === 'success' ? 'var(--success)' :
                            status === 'error' ? 'var(--error)' :
                                '#eab308'
                    }}>
                        <div className="flex items-center gap-2">
                            <span>{statusDisplay.icon}</span>
                            <span className="font-semibold">{statusDisplay.text}</span>
                        </div>
                        {txHash && (
                            <div className="text-xs mt-1 opacity-80">
                                Tx: {txHash.slice(0, 10)}...{txHash.slice(-8)}
                            </div>
                        )}
                    </div>
                )}

                {/* 错误信息 */}
                {error && status === 'error' && (
                    <div className="text-sm p-3 rounded-lg" style={{
                        background: 'rgba(239, 68, 68, 0.1)',
                        color: 'var(--error)'
                    }}>
                        {error}
                    </div>
                )}

                {/* 提示 */}
                <div className="text-xs p-3 rounded-lg" style={{
                    background: 'rgba(234, 179, 8, 0.1)',
                    color: '#eab308'
                }}>
                    <strong>💡 Permit2 优势：</strong> 一次授权 Permit2，所有集成应用共享。
                    签名有时间限制，更安全！
                </div>
            </div>
        </div>
    );
}
