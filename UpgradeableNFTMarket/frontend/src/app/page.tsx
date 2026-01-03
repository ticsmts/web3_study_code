'use client';

import { useState, useEffect } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useSignTypedData } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import { ZZTokenABI, ZZNFTABI, NFTMarketABI, CONTRACT_ADDRESSES, LISTING_PERMIT_TYPES } from '@/contracts';

type Tab = 'market' | 'mynfts' | 'mint' | 'list' | 'transfer';

interface Listing {
  seller: string;
  active: boolean;
  nft: string;
  tokenId: bigint;
  payToken: string;
  price: bigint;
}

export default function Home() {
  const [activeTab, setActiveTab] = useState<Tab>('market');
  const [txStatus, setTxStatus] = useState('');
  const { address, isConnected } = useAccount();

  // Form states
  const [transferTo, setTransferTo] = useState('');
  const [transferAmount, setTransferAmount] = useState('');
  const [mintTo, setMintTo] = useState('');
  const [listTokenId, setListTokenId] = useState('');
  const [listPrice, setListPrice] = useState('');
  const [useSignature, setUseSignature] = useState(false);
  const [sigDeadline, setSigDeadline] = useState('');
  const [signedData, setSignedData] = useState<{ v: number; r: string; s: string } | null>(null);

  // Contract reads
  const { data: tokenBalance, refetch: refetchBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.TOKEN, abi: ZZTokenABI, functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: nftBalance, refetch: refetchNFTBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: nextListingId, refetch: refetchListings } = useReadContract({
    address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'nextListingId',
  });

  const { data: totalNFTs, refetch: refetchTotalNFTs } = useReadContract({
    address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'getCurrentTokenId',
  });

  const { data: marketVersion } = useReadContract({
    address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'version',
  });

  const { data: sellerNonce } = useReadContract({
    address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'getSellerNonce',
    args: address ? [address] : undefined,
  });

  const { data: isApprovedForAll, refetch: refetchApproval } = useReadContract({
    address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'isApprovedForAll',
    args: address ? [address, CONTRACT_ADDRESSES.MARKET] : undefined,
  });

  const { data: tokenAllowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.TOKEN, abi: ZZTokenABI, functionName: 'allowance',
    args: address ? [address, CONTRACT_ADDRESSES.MARKET] : undefined,
  });

  // Contract writes
  const { writeContract, data: txHash, isPending, reset } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });
  const { signTypedData, data: signature, isPending: isSigning } = useSignTypedData();

  // Handle signature
  useEffect(() => {
    if (signature) {
      const r = signature.slice(0, 66);
      const s = '0x' + signature.slice(66, 130);
      const v = parseInt(signature.slice(130, 132), 16);
      setSignedData({ v, r, s });
      setTxStatus('签名已生成！点击提交上架。');
    }
  }, [signature]);

  // Handle tx success
  useEffect(() => {
    if (isSuccess) {
      setTxStatus('交易已确认！');
      refetchBalance(); refetchNFTBalance(); refetchListings(); refetchApproval(); refetchAllowance(); refetchTotalNFTs();
      setTimeout(() => { setTxStatus(''); reset(); }, 3000);
    }
  }, [isSuccess]);

  const handleTransfer = () => {
    if (!transferTo || !transferAmount) return;
    writeContract({ address: CONTRACT_ADDRESSES.TOKEN, abi: ZZTokenABI, functionName: 'transfer', args: [transferTo as `0x${string}`, parseEther(transferAmount)] });
    setTxStatus('发送转账中...');
  };

  const handleApproveTokens = (amount: string) => {
    writeContract({ address: CONTRACT_ADDRESSES.TOKEN, abi: ZZTokenABI, functionName: 'approve', args: [CONTRACT_ADDRESSES.MARKET, parseEther(amount)] });
    setTxStatus('授权代币中...');
  };

  const handleMint = () => {
    const toAddr = mintTo || address;
    if (!toAddr) return;
    writeContract({ address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'mint', args: [toAddr as `0x${string}`] });
    setTxStatus('铸造 NFT 中...');
  };

  const handleApproveNFT = (tokenId: string) => {
    writeContract({ address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'approve', args: [CONTRACT_ADDRESSES.MARKET, BigInt(tokenId)] });
    setTxStatus('授权 NFT 中...');
  };

  const handleSetApprovalForAll = () => {
    writeContract({ address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'setApprovalForAll', args: [CONTRACT_ADDRESSES.MARKET, true] });
    setTxStatus('设置批量授权中...');
  };

  const handleList = () => {
    if (!listTokenId || !listPrice) return;
    writeContract({ address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'list', args: [CONTRACT_ADDRESSES.NFT, BigInt(listTokenId), CONTRACT_ADDRESSES.TOKEN, parseEther(listPrice)] });
    setTxStatus('上架 NFT (托管模式)...');
  };

  const handleSignListing = async () => {
    if (!listTokenId || !listPrice || !address) return;
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
    setSigDeadline(deadline.toString());
    signTypedData({
      domain: { name: 'NFTMarketV2', version: '1', chainId: 11155111, verifyingContract: CONTRACT_ADDRESSES.MARKET },
      types: LISTING_PERMIT_TYPES,
      primaryType: 'ListingPermit',
      message: { nftContract: CONTRACT_ADDRESSES.NFT, tokenId: BigInt(listTokenId), payToken: CONTRACT_ADDRESSES.TOKEN, price: parseEther(listPrice), deadline, nonce: (sellerNonce as bigint) || BigInt(0) },
    });
    setTxStatus('请签署上架许可...');
  };

  const handleSubmitSignatureListing = () => {
    if (!signedData || !sigDeadline || !listTokenId || !listPrice) return;
    writeContract({
      address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'listWithSignature',
      args: [CONTRACT_ADDRESSES.NFT, BigInt(listTokenId), CONTRACT_ADDRESSES.TOKEN, parseEther(listPrice), BigInt(sigDeadline), signedData.v, signedData.r as `0x${string}`, signedData.s as `0x${string}`],
    });
    setTxStatus('提交签名上架中...');
    setSignedData(null);
  };

  const handleBuy = (listingId: number, price: bigint) => {
    writeContract({ address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'buyNFT', args: [BigInt(listingId), price] });
    setTxStatus('购买 NFT 中...');
  };

  const tabs: { id: Tab; label: string; icon: string }[] = [
    { id: 'market', label: '市场', icon: '🛒' },
    { id: 'mynfts', label: '我的NFT', icon: '🖼️' },
    { id: 'mint', label: '铸造', icon: '🎨' },
    { id: 'list', label: '上架', icon: '📋' },
    { id: 'transfer', label: '转账', icon: '💸' },
  ];

  return (
    <main className="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      {/* Header */}
      <header className="sticky top-0 z-50 backdrop-blur-lg bg-slate-900/80 border-b border-purple-500/20">
        <div className="max-w-7xl mx-auto px-4 py-4 flex justify-between items-center">
          <div className="flex items-center gap-3">
            <span className="text-2xl">🏪</span>
            <h1 className="text-xl font-bold bg-gradient-to-r from-pink-500 to-violet-500 bg-clip-text text-transparent">
              Upgradeable NFT Market
            </h1>
            {typeof marketVersion === 'string' && <span className="text-xs text-purple-400 bg-purple-500/20 px-2 py-1 rounded-full">v{marketVersion}</span>}
          </div>
          <ConnectButton />
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 py-8">
        {/* Status Alert */}
        {txStatus && (
          <div className={`mb-6 p-4 rounded-xl border ${isSuccess ? 'bg-green-500/20 border-green-500/50 text-green-300' : 'bg-yellow-500/20 border-yellow-500/50 text-yellow-300'}`}>
            {isPending || isConfirming ? '⏳ ' : isSuccess ? '✅ ' : '📝 '}{txStatus}
          </div>
        )}

        {isConnected ? (
          <>
            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
              <StatCard label="代币余额" value={`${tokenBalance ? formatEther(tokenBalance as bigint) : '0'} ZZT`} />
              <StatCard label="NFT 数量" value={`${nftBalance?.toString() || '0'} 个`} />
              <StatCard label="市场上架数" value={`${nextListingId?.toString() || '0'} 个`} />
              <StatCard label="市场授权" value={isApprovedForAll ? '✅ 已授权' : '❌ 未授权'} />
            </div>

            {/* Tabs */}
            <div className="flex gap-2 mb-8 bg-slate-800/50 p-2 rounded-2xl">
              {tabs.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex-1 py-3 px-4 rounded-xl font-medium transition-all ${activeTab === tab.id ? 'bg-gradient-to-r from-pink-500 to-violet-500 text-white shadow-lg' : 'text-slate-400 hover:bg-slate-700/50'}`}
                >
                  {tab.icon} {tab.label}
                </button>
              ))}
            </div>

            {/* Market Tab */}
            {activeTab === 'market' && (
              <div>
                <h2 className="text-2xl font-bold text-white mb-6">🛒 NFT 市场</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {nextListingId && Number(nextListingId) > 0 ? (
                    Array.from({ length: Number(nextListingId) }, (_, i) => (
                      <ListingCard key={i} listingId={i} onBuy={handleBuy} onApprove={handleApproveTokens} tokenAllowance={tokenAllowance as bigint} userAddress={address} />
                    ))
                  ) : (
                    <div className="col-span-full">
                      {/* Demo Guide */}
                      <div className="bg-slate-800/50 backdrop-blur border border-purple-500/20 rounded-2xl p-6 mb-6">
                        <h3 className="text-xl font-bold text-white mb-4">📖 如何测试购买功能</h3>
                        <div className="space-y-3 text-slate-300">
                          <p className="flex items-center gap-2"><span className="bg-pink-500/20 text-pink-400 px-2 py-0.5 rounded">步骤 1</span> 点击 <b>铸造</b> 标签，铸造一个 NFT</p>
                          <p className="flex items-center gap-2"><span className="bg-pink-500/20 text-pink-400 px-2 py-0.5 rounded">步骤 2</span> 点击 <b>上架</b> 标签，授权并上架 NFT</p>
                          <p className="flex items-center gap-2"><span className="bg-pink-500/20 text-pink-400 px-2 py-0.5 rounded">步骤 3</span> 返回 <b>市场</b> 标签，即可看到购买按钮</p>
                        </div>
                        <div className="mt-4 flex gap-3">
                          <button onClick={() => setActiveTab('mint')} className="px-4 py-2 bg-gradient-to-r from-pink-500 to-violet-500 text-white rounded-xl hover:shadow-lg transition-all">去铸造 NFT →</button>
                        </div>
                      </div>
                      {/* Demo Card Preview */}
                      <div className="bg-slate-800/30 border border-dashed border-purple-500/30 rounded-2xl p-6 text-center">
                        <p className="text-slate-500 mb-4">👇 上架后，NFT 卡片将显示为</p>
                        <div className="max-w-xs mx-auto bg-slate-800/50 border border-purple-500/20 rounded-2xl overflow-hidden">
                          <div className="h-32 bg-gradient-to-br from-purple-600 to-pink-600 flex items-center justify-center text-4xl">🖼️</div>
                          <div className="p-3">
                            <span className="font-bold text-white">NFT #1</span>
                            <p className="text-lg font-bold text-transparent bg-gradient-to-r from-pink-400 to-violet-400 bg-clip-text">100 ZZT</p>
                          </div>
                          <div className="p-3 border-t border-purple-500/20">
                            <button disabled className="w-full py-2 bg-gradient-to-r from-pink-500 to-violet-500 text-white rounded-xl opacity-50">立即购买</button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* My NFTs Tab */}
            {activeTab === 'mynfts' && (
              <div>
                <h2 className="text-2xl font-bold text-white mb-6">🖼️ 我的 NFT</h2>
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {totalNFTs && Number(totalNFTs) > 1 ? (
                    Array.from({ length: Number(totalNFTs) - 1 }, (_, i) => (
                      <OwnedNFTCard key={i + 1} tokenId={BigInt(i + 1)} userAddress={address} onList={(id) => { setListTokenId(id); setActiveTab('list'); }} />
                    ))
                  ) : (
                    <div className="col-span-full text-center py-16 text-slate-400">您还没有任何 NFT。</div>
                  )}
                </div>
              </div>
            )}

            {/* Mint Tab */}
            {activeTab === 'mint' && (
              <Card title="🎨 铸造 NFT">
                <Input label="接收地址（留空为自己）" placeholder="0x..." value={mintTo} onChange={setMintTo} />
                <Button onClick={handleMint} disabled={isPending || isConfirming}>铸造 NFT</Button>
              </Card>
            )}

            {/* List Tab */}
            {activeTab === 'list' && (
              <div className="space-y-6">
                <Card title="第一步：授权">
                  <p className="text-slate-400 mb-4">市场授权状态：{isApprovedForAll ? '✅ 已授权' : '❌ 未授权'}</p>
                  {!isApprovedForAll && <Button variant="secondary" onClick={handleSetApprovalForAll} disabled={isPending}>设置批量授权</Button>}
                </Card>
                <Card title="第二步：上架 NFT">
                  <Input label="Token ID" type="number" placeholder="1" value={listTokenId} onChange={setListTokenId} />
                  <Input label="价格 (ZZT)" placeholder="100" value={listPrice} onChange={setListPrice} />
                  <label className="flex items-center gap-2 text-slate-300 mb-4">
                    <input type="checkbox" checked={useSignature} onChange={(e) => setUseSignature(e.target.checked)} className="rounded" />
                    使用签名上架 (V2)
                  </label>
                  {!useSignature ? (
                    <div className="flex gap-3">
                      <Button variant="secondary" onClick={() => handleApproveNFT(listTokenId)} disabled={!listTokenId || isPending}>1. 授权</Button>
                      <Button onClick={handleList} disabled={!listTokenId || !listPrice || isPending}>2. 上架 (托管)</Button>
                    </div>
                  ) : (
                    <>
                      {!signedData ? (
                        <Button onClick={handleSignListing} disabled={!listTokenId || !listPrice || isSigning || !isApprovedForAll}>{isSigning ? '签名中...' : '签名上架'}</Button>
                      ) : (
                        <Button variant="success" onClick={handleSubmitSignatureListing} disabled={isPending}>提交签名上架</Button>
                      )}
                      {signedData && <p className="text-green-400 text-sm mt-2">✅ 签名已就绪，截止时间：{sigDeadline}</p>}
                    </>
                  )}
                </Card>
              </div>
            )}

            {/* Transfer Tab */}
            {activeTab === 'transfer' && (
              <Card title="💸 转账代币">
                <Input label="接收地址" placeholder="0x..." value={transferTo} onChange={setTransferTo} />
                <Input label="数量 (ZZT)" placeholder="100" value={transferAmount} onChange={setTransferAmount} />
                <Button onClick={handleTransfer} disabled={!transferTo || !transferAmount || isPending}>转账</Button>
              </Card>
            )}
          </>
        ) : (
          <div className="text-center py-20">
            <h2 className="text-3xl font-bold text-white mb-4">欢迎来到可升级 NFT 市场</h2>
            <p className="text-slate-400 mb-8">连接钱包开始交易 NFT</p>
            <ConnectButton />
          </div>
        )}
      </div>
    </main>
  );
}

// Components
function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-slate-800/50 backdrop-blur border border-purple-500/20 rounded-2xl p-4">
      <p className="text-slate-400 text-sm">{label}</p>
      <p className="text-xl font-bold text-transparent bg-gradient-to-r from-pink-400 to-violet-400 bg-clip-text">{value}</p>
    </div>
  );
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-slate-800/50 backdrop-blur border border-purple-500/20 rounded-2xl p-6 max-w-lg">
      <h3 className="text-xl font-bold text-white mb-4">{title}</h3>
      {children}
    </div>
  );
}

function Input({ label, value, onChange, placeholder, type = 'text' }: { label: string; value: string; onChange: (v: string) => void; placeholder?: string; type?: string }) {
  return (
    <div className="mb-4">
      <label className="block text-slate-400 text-sm mb-2">{label}</label>
      <input type={type} value={value} onChange={(e) => onChange(e.target.value)} placeholder={placeholder}
        className="w-full px-4 py-3 bg-slate-700/50 border border-purple-500/30 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:border-pink-500 transition-colors" />
    </div>
  );
}

function Button({ children, onClick, disabled, variant = 'primary' }: { children: React.ReactNode; onClick: () => void; disabled?: boolean; variant?: 'primary' | 'secondary' | 'success' }) {
  const base = 'px-6 py-3 rounded-xl font-medium transition-all disabled:opacity-50 disabled:cursor-not-allowed';
  const variants = {
    primary: 'bg-gradient-to-r from-pink-500 to-violet-500 text-white hover:shadow-lg hover:shadow-pink-500/25',
    secondary: 'bg-slate-700 text-white hover:bg-slate-600 border border-purple-500/30',
    success: 'bg-gradient-to-r from-green-500 to-emerald-500 text-white hover:shadow-lg',
  };
  return <button onClick={onClick} disabled={disabled} className={`${base} ${variants[variant]}`}>{children}</button>;
}

function OwnedNFTCard({ tokenId, userAddress, onList }: { tokenId: bigint; userAddress?: string; onList: (id: string) => void }) {
  const { data: owner } = useReadContract({ address: CONTRACT_ADDRESSES.NFT, abi: ZZNFTABI, functionName: 'ownerOf', args: [tokenId] });
  if (!owner || (owner as string).toLowerCase() !== userAddress?.toLowerCase()) return null;

  return (
    <div className="bg-slate-800/50 backdrop-blur border border-purple-500/20 rounded-2xl overflow-hidden hover:border-pink-500/50 transition-all">
      <div className="h-48 bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-6xl">🖼️</div>
      <div className="p-4">
        <h3 className="font-bold text-white text-lg">NFT #{tokenId.toString()}</h3>
        <p className="text-slate-400 text-sm mb-4">由您拥有</p>
        <button onClick={() => onList(tokenId.toString())} className="w-full py-2 bg-slate-700 text-white rounded-xl hover:bg-slate-600 transition-colors">去上架</button>
      </div>
    </div>
  );
}

function ListingCard({ listingId, onBuy, onApprove, tokenAllowance, userAddress }: { listingId: number; onBuy: (id: number, price: bigint) => void; onApprove: (amount: string) => void; tokenAllowance: bigint; userAddress?: string }) {
  const { data: listing } = useReadContract({ address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'getListing', args: [BigInt(listingId)] });
  const { data: isSignature } = useReadContract({ address: CONTRACT_ADDRESSES.MARKET, abi: NFTMarketABI, functionName: 'isSignatureListing', args: [BigInt(listingId)] });

  if (!listing) return null;
  const L = listing as Listing;
  if (!L.active) return null;

  const needsApproval = !tokenAllowance || tokenAllowance < L.price;
  const isSeller = userAddress?.toLowerCase() === L.seller.toLowerCase();

  return (
    <div className="bg-slate-800/50 backdrop-blur border border-purple-500/20 rounded-2xl overflow-hidden hover:border-pink-500/50 transition-all hover:shadow-xl hover:shadow-pink-500/10">
      <div className="h-48 bg-gradient-to-br from-purple-600 to-pink-600 flex items-center justify-center text-6xl">🖼️</div>
      <div className="p-4">
        <div className="flex items-center gap-2 mb-2">
          <span className="font-bold text-white">NFT #{L.tokenId.toString()}</span>
          {isSignature === true && <span className="text-xs bg-pink-500/20 text-pink-400 px-2 py-0.5 rounded-full">签名</span>}
        </div>
        <p className="text-xl font-bold text-transparent bg-gradient-to-r from-pink-400 to-violet-400 bg-clip-text">{formatEther(L.price)} ZZT</p>
        <p className="text-slate-500 text-sm">卖家: {L.seller.slice(0, 6)}...{L.seller.slice(-4)}</p>
      </div>
      <div className="p-4 border-t border-purple-500/20">
        {!isSeller ? (
          needsApproval ? (
            <button onClick={() => onApprove(formatEther(L.price))} className="w-full py-2 bg-slate-700 text-white rounded-xl hover:bg-slate-600 transition-colors">授权 {formatEther(L.price)} ZZT</button>
          ) : (
            <button onClick={() => onBuy(listingId, L.price)} className="w-full py-2 bg-gradient-to-r from-pink-500 to-violet-500 text-white rounded-xl hover:shadow-lg transition-all">立即购买</button>
          )
        ) : (
          <span className="block text-center text-slate-500">您的上架</span>
        )}
      </div>
    </div>
  );
}
