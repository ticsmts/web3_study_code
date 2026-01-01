'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useReadContract, useBlockNumber } from 'wagmi';
import { formatEther } from 'viem';
import { useEffect } from 'react';
import { CONTRACTS, TOKEN_ABI, NFT_ABI, MARKET_ABI } from '@/config/contracts';
import ListNFT from '@/components/ListNFT';
import NFTListings from '@/components/NFTListings';
import MerkleClaimNFT from '@/components/MerkleClaimNFT';
import WhitelistManager from '@/components/WhitelistManager';
import AdminTools from '@/components/AdminTools';

export default function Home() {
  const { address, isConnected } = useAccount();
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

  // 读取市场 admin
  const { data: admin } = useReadContract({
    address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
    abi: MARKET_ABI,
    functionName: 'admin',
  });

  // 读取 Merkle Root
  const { data: merkleRoot } = useReadContract({
    address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
    abi: MARKET_ABI,
    functionName: 'merkleRoot',
  });

  // 当区块变化时刷新余额
  useEffect(() => {
    if (blockNumber) {
      refetchTokenBalance();
      refetchNftBalance();
    }
  }, [blockNumber, refetchTokenBalance, refetchNftBalance]);

  const tokenBalanceFormatted = tokenBalance ? formatEther(tokenBalance as bigint) : '0';
  const isAdmin = address && admin && address.toLowerCase() === (admin as string).toLowerCase();

  return (
    <div className="min-h-screen">
      {/* Header */}
      <header className="border-b" style={{ borderColor: 'var(--border)' }}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold gradient-text">🎁 AirdropMerkleNFTMarket</h1>
              <p className="mt-2" style={{ color: 'var(--text-secondary)' }}>
                Merkle 白名单 + Permit + Multicall 购买
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
            <h2 className="text-3xl font-bold mb-4 gradient-text">Welcome to AirdropMerkleNFTMarket</h2>
            <p className="text-xl mb-8" style={{ color: 'var(--text-secondary)' }}>
              请连接你的钱包开始使用
            </p>
          </div>
        ) : (
          <>
            {/* Stats Section */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
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
                <div className="text-2xl font-bold" style={{ color: isAdmin ? 'var(--success)' : 'var(--text-primary)' }}>
                  {isAdmin ? 'Admin' : '普通用户'}
                </div>
              </div>
              <div className="stat-card">
                <div className="text-sm mb-2" style={{ color: 'var(--text-secondary)' }}>
                  🌳 Merkle Root
                </div>
                <div className="text-sm font-mono break-all" style={{ color: 'var(--accent-primary)' }}>
                  {merkleRoot ? `${(merkleRoot as string).slice(0, 10)}...` : 'N/A'}
                </div>
              </div>
            </div>

            {/* NFT Listings */}
            <div className="mb-8">
              <NFTListings />
            </div>

            {/* Info Banner */}
            <div className="mb-8 p-4 rounded-xl border" style={{
              background: 'linear-gradient(135deg, rgba(16, 185, 129, 0.05), rgba(99, 102, 241, 0.05))',
              borderColor: 'rgba(16, 185, 129, 0.2)'
            }}>
              <h3 className="text-lg font-bold mb-2 flex items-center gap-2" style={{ color: 'var(--success)' }}>
                <span>💡</span>
                <span>Merkle 白名单购买流程</span>
              </h3>
              <div className="text-sm leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                <ol className="list-decimal ml-4 space-y-1">
                  <li><strong>卖家</strong>上架 NFT，设置原始价格</li>
                  <li><strong>白名单用户</strong>获取 Merkle Proof（可从管理员获取）</li>
                  <li>使用「白名单购买」组件，通过 <strong>Multicall</strong> 一次性完成：
                    <ul className="list-disc ml-6 mt-1">
                      <li>EIP-2612 Permit 签名授权</li>
                      <li>Merkle 验证 + 50% 折扣购买</li>
                    </ul>
                  </li>
                </ol>
              </div>
            </div>

            {/* Action Cards Grid - Row 1: List & Buy */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
              <ListNFT />
              <MerkleClaimNFT />
            </div>

            {/* Whitelist Management & Admin Tools */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <WhitelistManager />
              <AdminTools />
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
