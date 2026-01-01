'use client';

import { useReadContract } from 'wagmi';
import { formatEther } from 'viem';
import { CONTRACTS, MARKET_ABI } from '@/config/contracts';

interface Listing {
    seller: string;
    active: boolean;
    nft: string;
    tokenId: bigint;
    payToken: string;
    price: bigint;
}

/**
 * NFTListings Component
 * 显示市场上的 NFT Listings
 */
export default function NFTListings() {
    const { data: nextListingId } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'nextListingId',
    });

    const listingIds = nextListingId ? Array.from({ length: Math.min(Number(nextListingId), 10) }, (_, i) => i) : [];

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">🏪 NFT 市场</h3>
                <span className="badge badge-primary">{listingIds.length} Listings</span>
            </div>

            <div className="space-y-3">
                {listingIds.length === 0 ? (
                    <p className="text-sm text-center py-8" style={{ color: 'var(--text-secondary)' }}>
                        暂无上架的 NFT
                    </p>
                ) : (
                    listingIds.map((id) => (
                        <ListingItem key={id} listingId={id} />
                    ))
                )}
            </div>
        </div>
    );
}

function ListingItem({ listingId }: { listingId: number }) {
    const { data: listing } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'getListing',
        args: [BigInt(listingId)],
    });

    if (!listing) return null;

    const l = listing as Listing;
    const originalPrice = Number(l.price) / 1e18;
    const discountedPrice = originalPrice / 2;

    return (
        <div
            className="p-4 rounded-lg border transition-all"
            style={{
                background: l.active ? 'rgba(99, 102, 241, 0.05)' : 'rgba(100, 100, 100, 0.05)',
                borderColor: l.active ? 'rgba(99, 102, 241, 0.2)' : 'rgba(100, 100, 100, 0.2)',
                opacity: l.active ? 1 : 0.6,
            }}
        >
            <div className="flex items-center justify-between">
                <div>
                    <div className="flex items-center gap-2">
                        <span className="text-lg">🎨</span>
                        <span className="font-semibold">Token #{l.tokenId.toString()}</span>
                        {l.active ? (
                            <span className="badge badge-success" style={{ fontSize: '0.7rem' }}>在售</span>
                        ) : (
                            <span className="badge" style={{ fontSize: '0.7rem', background: 'rgba(100,100,100,0.2)' }}>已售</span>
                        )}
                    </div>
                    <div className="text-sm mt-1" style={{ color: 'var(--text-secondary)' }}>
                        Listing #{listingId} · 卖家: {l.seller.slice(0, 8)}...
                    </div>
                </div>
                <div className="text-right">
                    <div className="text-sm line-through" style={{ color: 'var(--text-secondary)' }}>
                        {originalPrice.toFixed(2)} ZZ
                    </div>
                    <div className="text-lg font-bold" style={{ color: 'var(--success)' }}>
                        {discountedPrice.toFixed(2)} ZZ
                    </div>
                    <div className="text-xs" style={{ color: 'var(--accent-primary)' }}>
                        50% 折扣
                    </div>
                </div>
            </div>
        </div>
    );
}
