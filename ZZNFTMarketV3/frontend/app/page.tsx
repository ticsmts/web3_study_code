'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useReadContract, useBlockNumber } from 'wagmi';
import { formatEther } from 'viem';
import { useEffect } from 'react';
import { CONTRACTS, TOKEN_ABI, NFT_ABI, MARKET_ABI } from '@/config/contracts';
import ListNFT from '@/components/ListNFT';
import WhitelistSign from '@/components/WhitelistSign';
import PermitBuy from '@/components/PermitBuy';
import NFTListings from '@/components/NFTListings';

export default function Home() {
  const { address, isConnected } = useAccount();

  // 监听区块变化以自动刷新数据
  const { data: blockNumber } = useBlockNumber({ watch: true });

  // 读取用户代币余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: CONTRACTS.TOKEN_ADDRESS as `0x${string}`,
    abi: TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 读取用户 NFT 数量
  const { data: nftBalance, refetch: refetchNftBalance } = useReadContract({
    address: CONTRACTS.NFT_ADDRESS as `0x${string}`,
    abi: NFT_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 读取市场 signer
  const { data: signer } = useReadContract({
    address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
    abi: MARKET_ABI,
    functionName: 'signer',
  });

  // 当区块变化时刷新余额
  useEffect(() => {
    if (blockNumber) {
      refetchTokenBalance();
      refetchNftBalance();
    }
  }, [blockNumber, refetchTokenBalance, refetchNftBalance]);

  const tokenBalanceFormatted = tokenBalance ? formatEther(tokenBalance as bigint) : '0';
  const isSigner = address && signer && address.toLowerCase() === (signer as string).toLowerCase();

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b" style={{ borderColor: 'var(--border)' }}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold gradient-text">🎨 ZZNFTMarket V3</h1>
              <p className="mt-2" style={{ color: 'var(--text-secondary)' }}>
                NFT 市场 - 白名单 Permit 购买
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
            <h2 className="text-3xl font-bold mb-4 gradient-text">Welcome to ZZNFTMarket V3</h2>
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
                  💰 ZZ Token 余额
                </div>
                <div className="text-2xl font-bold">{parseFloat(tokenBalanceFormatted).toFixed(2)} ZZ</div>
              </div>
              <div className="stat-card">
                <div className="text-sm mb-2" style={{ color: 'var(--text-secondary)' }}>
                  🎨 我的 NFT
                </div>
                <div className="text-2xl font-bold" style={{ color: 'var(--accent-secondary)' }}>
                  {nftBalance?.toString() || '0'} 个
                </div>
              </div>
              <div className="stat-card">
                <div className="text-sm mb-2" style={{ color: 'var(--text-secondary)' }}>
                  🔐 身份
                </div>
                <div className="text-2xl font-bold" style={{ color: isSigner ? 'var(--success)' : 'var(--text-primary)' }}>
                  {isSigner ? '项目方 (Signer)' : '普通用户'}
                </div>
              </div>
            </div>

            {/* NFT Listings */}
            <div className="mb-8">
              <NFTListings />
            </div>

            {/* Info Banner */}
            <div className="mb-8 p-4 rounded-xl border" style={{
              background: 'linear-gradient(135deg, rgba(99, 102, 241, 0.05), rgba(139, 92, 246, 0.05))',
              borderColor: 'rgba(99, 102, 241, 0.2)'
            }}>
              <h3 className="text-lg font-bold mb-2 flex items-center gap-2" style={{ color: 'var(--accent-primary)' }}>
                <span>💡</span>
                <span>白名单购买流程</span>
              </h3>
              <div className="text-sm leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                <ol className="list-decimal ml-4 space-y-1">
                  <li><strong>卖家</strong>上架 NFT，设置价格</li>
                  <li><strong>项目方 (Signer)</strong> 使用「白名单签名」组件为指定买家生成签名</li>
                  <li><strong>白名单买家</strong>获得签名参数后，使用「白名单购买」组件完成购买</li>
                </ol>
              </div>
            </div>

            {/* Action Cards Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <ListNFT />
              <WhitelistSign />
              <PermitBuy />
            </div>
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t mt-20" style={{ borderColor: 'var(--border)' }}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 text-center" style={{ color: 'var(--text-secondary)' }}>
          <p>Built with Next.js, RainbowKit, Wagmi & ❤️</p>
          <p className="mt-2 text-sm">
            Market: {CONTRACTS.MARKET_ADDRESS.slice(0, 6)}...{CONTRACTS.MARKET_ADDRESS.slice(-4)}
          </p>
        </div>
      </footer>
    </div>
  );
}
