'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { CONTRACTS, TOKEN_ABI } from '@/config/contracts';

export default function V2Callback() {
    const { address } = useAccount();
    const [amount, setAmount] = useState('');

    const { data: hash, isPending, writeContract, error } = useWriteContract();

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    const handleTransferWithCallback = () => {
        if (!amount || parseFloat(amount) <= 0) {
            alert('请输入有效金额');
            return;
        }

        try {
            writeContract({
                address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                abi: TOKEN_ABI,
                functionName: 'transferWithCallback',
                args: [
                    CONTRACTS.BANK_ADDRESS as `0x${string}`,
                    parseEther(amount),
                    '0x' as `0x${string}`, // empty bytes data
                ],
            });
        } catch (err) {
            console.error('Transfer with callback error:', err);
        }
    };

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">V2: TransferWithCallback</h3>
                <span className="badge badge-success">1 Step</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                使用带回调的转账功能。转账完成后自动触发 TokenBank 的回调函数完成入账，无需预先授权。
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
                        disabled={isPending || isConfirming}
                    />
                </div>

                {/* Action button */}
                <button
                    className="btn-primary w-full"
                    onClick={handleTransferWithCallback}
                    disabled={!address || isPending || isConfirming || !amount}
                >
                    {isPending ? (
                        <div className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            <span>等待确认...</span>
                        </div>
                    ) : isConfirming ? (
                        <div className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            <span>交易确认中...</span>
                        </div>
                    ) : (
                        '💸 TransferWithCallback'
                    )}
                </button>

                {/* Transaction status */}
                {hash && (
                    <div className="text-sm p-3 rounded-lg" style={{
                        background: isSuccess ? 'rgba(16, 185, 129, 0.1)' : 'rgba(99, 102, 241, 0.1)',
                        color: isSuccess ? 'var(--success)' : 'var(--accent-primary)'
                    }}>
                        <div className="font-semibold mb-1">
                            {isSuccess ? '✅ 存款成功！' : '⏳ 交易处理中...'}
                        </div>
                        <div className="text-xs opacity-80">
                            交易哈希: {hash.slice(0, 10)}...{hash.slice(-8)}
                        </div>
                    </div>
                )}

                {/* Error display */}
                {error && (
                    <div className="text-sm p-3 rounded-lg" style={{
                        background: 'rgba(239, 68, 68, 0.1)',
                        color: 'var(--error)'
                    }}>
                        <div className="font-semibold mb-1">❌ 交易失败</div>
                        <div className="text-xs opacity-80">
                            {error.message.slice(0, 100)}
                        </div>
                    </div>
                )}

                {/* Explanation */}
                <div className="text-sm p-4 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.05)', color: 'var(--text-secondary)' }}>
                    <strong>工作原理：</strong>
                    <ol className="mt-2 space-y-1 ml-4">
                        <li>1. 用户调用 token.transferWithCallback(bank, amount, data)</li>
                        <li>2. Token 合约转账后自动调用 bank.tokensReceived()</li>
                        <li>3. Bank 自动完成记账，无需额外授权</li>
                        <li>4. <strong>优势</strong>：单笔交易完成存款，节省 gas</li>
                    </ol>
                </div>
            </div>
        </div>
    );
}
