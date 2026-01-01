import { useState } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'
import { BigBankV2ABI, CONTRACT_ADDRESS } from '../wagmi'
import './DepositForm.css'

export default function DepositForm() {
    const [amount, setAmount] = useState('')

    const { data: hash, writeContract, isPending, error } = useWriteContract()

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    })

    const handleDeposit = async (e: React.FormEvent) => {
        e.preventDefault()
        if (!amount || parseFloat(amount) < 0.001) {
            alert('最小存款金额为 0.001 ETH')
            return
        }

        writeContract({
            address: CONTRACT_ADDRESS,
            abi: BigBankV2ABI,
            functionName: 'deposit',
            value: parseEther(amount),
        })
    }

    return (
        <div className="deposit-form-card">
            <h3>💰 存款</h3>

            <form onSubmit={handleDeposit}>
                <div className="input-group">
                    <input
                        type="number"
                        step="0.001"
                        min="0.001"
                        placeholder="输入 ETH 金额"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        disabled={isPending || isConfirming}
                    />
                    <span className="input-suffix">ETH</span>
                </div>

                <button
                    type="submit"
                    className="deposit-button"
                    disabled={isPending || isConfirming || !amount}
                >
                    {isPending ? '确认中...' : isConfirming ? '交易处理中...' : '存款'}
                </button>
            </form>

            {isSuccess && (
                <div className="success-message">
                    ✅ 存款成功！
                </div>
            )}

            {error && (
                <div className="error-message">
                    ❌ 错误: {(error as Error).message.slice(0, 100)}
                </div>
            )}

            <p className="hint">最小存款金额: 0.001 ETH</p>
        </div>
    )
}
