import { useReadContract } from 'wagmi'
import { formatEther } from 'viem'
import { BigBankV2ABI, CONTRACT_ADDRESS } from '../wagmi'
import './TopDepositors.css'

export default function TopDepositors() {
    const { data, isLoading, refetch } = useReadContract({
        address: CONTRACT_ADDRESS,
        abi: BigBankV2ABI,
        functionName: 'getTopDepositors',
    })

    const formatAddress = (address: string) => {
        return `${address.slice(0, 6)}...${address.slice(-4)}`
    }

    if (isLoading) {
        return (
            <div className="top-depositors-card">
                <h3>🏆 存款排行榜</h3>
                <div className="loading">加载中...</div>
            </div>
        )
    }

    const [users, amounts] = data || [[], []]

    return (
        <div className="top-depositors-card">
            <div className="card-header">
                <h3>🏆 存款排行榜 TOP 10</h3>
                <button className="refresh-button" onClick={() => refetch()}>
                    🔄 刷新
                </button>
            </div>

            {users.length === 0 ? (
                <div className="empty-state">
                    <span className="empty-icon">📭</span>
                    <p>暂无存款记录</p>
                    <p className="hint">成为第一个存款用户！</p>
                </div>
            ) : (
                <div className="leaderboard">
                    {users.map((user: string, index: number) => (
                        <div key={user} className={`leaderboard-item rank-${index + 1}`}>
                            <div className="rank">
                                {index === 0 && '🥇'}
                                {index === 1 && '🥈'}
                                {index === 2 && '🥉'}
                                {index > 2 && <span className="rank-number">{index + 1}</span>}
                            </div>
                            <div className="user-info">
                                <span className="address">{formatAddress(user)}</span>
                            </div>
                            <div className="amount">
                                <span className="value">{formatEther(amounts[index])}</span>
                                <span className="unit">ETH</span>
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    )
}
