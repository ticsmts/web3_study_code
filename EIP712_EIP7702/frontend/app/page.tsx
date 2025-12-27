'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useReadContract } from 'wagmi';
import { formatEther } from 'viem';
import { CONTRACTS, TOKEN_ABI, BANK_ABI } from '@/config/contracts';
import V1Approve from '@/components/V1Approve';
import V2Callback from '@/components/V2Callback';
import V3Permit from '@/components/V3Permit';
import V4EIP7702 from '@/components/V4EIP7702';
import WithdrawSection from '@/components/WithdrawSection';

export default function Home() {
  const { address, isConnected } = useAccount();

  // 读取用户钱包余额
  const { data: balance } = useReadContract({
    address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 读取用户存款
  const { data: deposited } = useReadContract({
    address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
    abi: BANK_ABI,
    functionName: 'depositedOf',
    args: address ? [address] : undefined,
  });

  // 读取总存款
  const { data: totalDeposits } = useReadContract({
    address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
    abi: BANK_ABI,
    functionName: 'totalDeposits',
  });

  const walletBalance = balance ? formatEther(balance as bigint) : '0';
  const depositedAmount = deposited ? formatEther(deposited as bigint) : '0';
  const totalDepositsAmount = totalDeposits ? formatEther(totalDeposits as bigint) : '0';

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b" style={{ borderColor: 'var(--border)' }}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold gradient-text">🏦 TokenBank DApp</h1>
              <p className="mt-2" style={{ color: 'var(--text-secondary)' }}>
                探索四种不同的存款方式
              </p>
            </div>
            <ConnectButton />
          </div>
        </div>
      </header>

      {/* Main content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {!isConnected ? (
          <div className="text-center py-20">
            <div className="text-6xl mb-6">🔌</div>
            <h2 className="text-3xl font-bold mb-4 gradient-text">Welcome to TokenBank</h2>
            <p className="text-xl mb-8" style={{ color: 'var(--text-secondary)' }}>
              请连接你的钱包开始使用
            </p>
          </div>
        ) : (
          <>
            {/* Stats Section */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
              <div className="stat-card">
                <div className="text-sm mb-2" style={{ color: 'var(--text-secondary)' }}>
                  💼 钱包余额
                </div>
                <div className="text-2xl font-bold">{walletBalance} ZZ</div>
              </div>
              <div className="stat-card">
                <div className="text-sm mb-2" style={{ color: 'var(--text-secondary)' }}>
                  🏦 我的存款
                </div>
                <div className="text-2xl font-bold" style={{ color: 'var(--success)' }}>
                  {depositedAmount} ZZ
                </div>
              </div>
              <div className="stat-card">
                <div className="text-sm mb-2" style={{ color: 'var(--text-secondary)' }}>
                  📊 总存款
                </div>
                <div className="text-2xl font-bold" style={{ color: 'var(--accent-primary)' }}>
                  {totalDepositsAmount} ZZ
                </div>
              </div>
            </div>

            {/* Deposit Methods Grid */}
            <div className="mb-8">
              <h2 className="text-2xl font-bold mb-4 gradient-text">💳 Deposit Methods</h2>
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                <V1Approve />
                <V2Callback />
                <V3Permit />
                <V4EIP7702 />
              </div>
            </div>

            {/* Info Banner - moved below deposit methods */}
            <div className="mb-8 p-4 rounded-xl border" style={{
              background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.05), rgba(139, 92, 246, 0.05))',
              borderColor: 'rgba(99, 102, 241, 0.2)'
            }}>
              <h3 className="text-lg font-bold mb-2 flex items-center gap-2" style={{ color: 'var(--accent-primary)' }}>
                <span>💡</span>
                <span>关于这个 DApp</span>
              </h3>
              <p className="text-sm leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                这个应用演示了四种不同的代币存款方式，帮助你理解 ERC20 授权、回调和 EIP-2612 Permit 签名，以及EIP-7702 智能账户的区别。
                V3 使用离线签名 + 一笔交易是最优方案。
              </p>
            </div>

            {/* Withdraw Section - centered and compact */}
            <div className="flex justify-center">
              <div className="w-full max-w-md">
                <h2 className="text-2xl font-bold mb-4 gradient-text text-center">🔄 Withdraw</h2>
                <WithdrawSection />
              </div>
            </div>
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t mt-20" style={{ borderColor: 'var(--border)' }}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 text-center" style={{ color: 'var(--text-secondary)' }}>
          <p>Built with Next.js, RainbowKit, Wagmi & ❤️</p>
          <p className="mt-2 text-sm">
            Contract: {CONTRACTS.BANK_ADDRESS.slice(0, 6)}...{CONTRACTS.BANK_ADDRESS.slice(-4)}
          </p>
        </div>
      </footer>
    </div>
  );
}
