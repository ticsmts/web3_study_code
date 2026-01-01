import { useAccount, useReadContract } from 'wagmi'
import { formatEther } from 'viem'
import { BigBankV2ABI, CONTRACT_ADDRESS } from '../wagmi'
import './UserBalance.css'

export default function UserBalance() {
    const { address } = useAccount()

    const { data: balance, isLoading } = useReadContract({
        address: CONTRACT_ADDRESS,
        abi: BigBankV2ABI,
        functionName: 'getBalance',
        args: address ? [address] : undefined,
    })

    const { data: totalBalance } = useReadContract({
        address: CONTRACT_ADDRESS,
        abi: BigBankV2ABI,
        functionName: 'getTotalBalance',
    })

    return (
        <div className="user-balance-card">
            <h3>📊 账户信息</h3>

            <div className="balance-grid">
                <div className="balance-item">
                    <span className="label">我的存款</span>
                    <span className="value">
                        {isLoading ? '...' : balance ? formatEther(balance) : '0'} ETH
                    </span>
                </div>

                <div className="balance-item">
                    <span className="label">合约总余额</span>
                    <span className="value">
                        {totalBalance ? formatEther(totalBalance) : '0'} ETH
                    </span>
                </div>
            </div>
        </div>
    )
}
