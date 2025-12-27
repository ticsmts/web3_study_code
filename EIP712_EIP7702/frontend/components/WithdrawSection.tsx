'use client';

import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther } from 'viem';
import { CONTRACTS, BANK_ABI } from '@/config/contracts';

export default function WithdrawSection() {
    const { address } = useAccount();

    // 读取用户存款
    const { data: deposited, refetch } = useReadContract({
        address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
        abi: BANK_ABI,
        functionName: 'depositedOf',
        args: address ? [address] : undefined,
    });

    // Withdraw 交易
    const {
        data: hash,
        writeContract: withdraw,
        isPending,
    } = useWriteContract();

    const { isLoading: isConfirming } = useWaitForTransactionReceipt({
        hash,
        onReplaced: (replacement) => {
            console.log('Withdraw confirmed:', replacement);
            refetch();
        },
    });

    const handleWithdraw = async () => {
        try {
            await withdraw({
                address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                abi: BANK_ABI,
                functionName: 'withdraw',
            });
        } catch (error) {
            console.error('Withdraw failed:', error);
        }
    };

    const depositedAmount = deposited ? formatEther(deposited as bigint) : '0';
    const hasDeposits = deposited && deposited > BigInt(0);

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">💰 Withdraw</h3>
                <span className="badge badge-success">取款</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                将你在 TokenBank 中的存款取回到钱包。
            </p>

            <div className="space-y-4">
                {/* Deposited amount display */}
                <div className="stat-card">
                    <div className="text-sm" style={{ color: 'var(--text-secondary)' }}>您的存款</div>
                    <div className="text-3xl font-bold mt-2" style={{ color: hasDeposits ? 'var(--success)' : 'var(--text-secondary)' }}>
                        {depositedAmount} ZZ
                    </div>
                </div>

                {/* Withdraw button */}
                <button
                    className="btn-primary w-full"
                    onClick={handleWithdraw}
                    disabled={!address || !hasDeposits || isPending || isConfirming}
                >
                    {isPending || isConfirming ? (
                        <span className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            Withdrawing...
                        </span>
                    ) : hasDeposits ? (
                        '🏦 Withdraw All'
                    ) : (
                        '无可用存款'
                    )}
                </button>

                {/* Transaction status */}
                {hash && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ Withdraw tx: {hash.slice(0, 10)}...{hash.slice(-8)}
                    </div>
                )}
            </div>
        </div>
    );
}
