'use client';

import { useState } from 'react';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { CONTRACTS, TOKEN_ABI, BANK_ABI } from '@/config/contracts';

export default function V1Approve() {
    const { address } = useAccount();
    const [amount, setAmount] = useState('');
    const [step, setStep] = useState<'input' | 'approve' | 'deposit'>('input');

    // 读取当前 allowance
    const { data: allowance, refetch: refetchAllowance } = useReadContract({
        address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
        abi: TOKEN_ABI,
        functionName: 'allowance',
        args: address ? [address, CONTRACTS.BANK_ADDRESS as `0x${string}`] : undefined,
    });

    // Approve 交易
    const {
        data: approveHash,
        writeContract: approve,
        isPending: isApprovePending,
    } = useWriteContract();

    const { isLoading: isApproveConfirming } = useWaitForTransactionReceipt({
        hash: approveHash,
    });

    // Deposit 交易
    const {
        data: depositHash,
        writeContract: deposit,
        isPending: isDepositPending,
    } = useWriteContract();

    const { isLoading: isDepositConfirming } = useWaitForTransactionReceipt({
        hash: depositHash,
        onReplaced: (replacement) => {
            console.log('Deposit confirmed:', replacement);
            setStep('input');
            setAmount('');
            refetchAllowance();
        },
    });

    const handleApprove = async () => {
        if (!amount || parseFloat(amount) <= 0) return;

        try {
            await approve({
                address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
                abi: TOKEN_ABI,
                functionName: 'approve',
                args: [CONTRACTS.BANK_ADDRESS as `0x${string}`, parseEther(amount)],
            });
            setStep('deposit');
        } catch (error) {
            console.error('Approve failed:', error);
        }
    };

    const handleDeposit = async () => {
        try {
            await deposit({
                address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                abi: BANK_ABI,
                functionName: 'deposit',
            });
        } catch (error) {
            console.error('Deposit failed:', error);
        }
    };

    const currentAllowance = allowance ? formatEther(allowance as bigint) : '0';

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">V1: Approve + Deposit</h3>
                <span className="badge badge-warning">2 Steps</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                传统方式：首先授权 TokenBank 使用你的代币，然后调用 deposit 函数完成存款。
            </p>

            <div className="space-y-4">
                {/* Step indicator */}
                <div className="flex items-center gap-3 mb-4">
                    <div className={`flex items-center justify-center w-8 h-8 rounded-full text-sm font-bold ${step === 'approve' || step === 'deposit' ? 'bg-primary text-white' : 'bg-gray-700 text-gray-400'
                        }`} style={step === 'approve' || step === 'deposit' ? { background: 'var(--accent-primary)' } : {}}>
                        1
                    </div>
                    <div className="flex-1 h-1 bg-gray-700" style={step === 'deposit' ? { background: 'var(--accent-primary)' } : {}}></div>
                    <div className={`flex items-center justify-center w-8 h-8 rounded-full text-sm font-bold ${step === 'deposit' ? 'bg-primary text-white' : 'bg-gray-700 text-gray-400'
                        }`} style={step === 'deposit' ? { background: 'var(--accent-primary)' } : {}}>
                        2
                    </div>
                </div>

                {/* Current allowance */}
                <div className="stat-card">
                    <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>当前授权额度</div>
                    <div className="text-xl font-bold mt-1">{currentAllowance} ZZ</div>
                </div>

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
                        disabled={step !== 'input'}
                    />
                </div>

                {/* Action buttons */}
                <div className="flex gap-3">
                    {step === 'input' && (
                        <button
                            className="btn-primary flex-1"
                            onClick={handleApprove}
                            disabled={!address || !amount || parseFloat(amount) <= 0 || isApprovePending}
                        >
                            {isApprovePending ? (
                                <span className="flex items-center justify-center gap-2">
                                    <div className="spinner"></div>
                                    Approving...
                                </span>
                            ) : (
                                'Step 1: Approve'
                            )}
                        </button>
                    )}

                    {step === 'deposit' && (
                        <>
                            <button
                                className="btn-secondary"
                                onClick={() => {
                                    setStep('input');
                                    setAmount('');
                                }}
                            >
                                重新设置
                            </button>
                            <button
                                className="btn-primary flex-1"
                                onClick={handleDeposit}
                                disabled={!address || isDepositPending || isDepositConfirming}
                            >
                                {isDepositPending || isDepositConfirming ? (
                                    <span className="flex items-center justify-center gap-2">
                                        <div className="spinner"></div>
                                        Depositing...
                                    </span>
                                ) : (
                                    'Step 2: Deposit'
                                )}
                            </button>
                        </>
                    )}
                </div>

                {/* Transaction status */}
                {approveHash && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.1)', color: 'var(--accent-primary)' }}>
                        ✓ Approve tx: {approveHash.slice(0, 10)}...{approveHash.slice(-8)}
                    </div>
                )}
                {depositHash && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ Deposit tx: {depositHash.slice(0, 10)}...{depositHash.slice(-8)}
                    </div>
                )}
            </div>
        </div>
    );
}
