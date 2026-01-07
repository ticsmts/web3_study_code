'use client';

import { useState } from 'react';
import { GlassCard } from '../ui/GlassCard';
import { usePoolPrice } from '@/hooks/usePoolPrice';
import { CONTRACTS } from '@/lib/contracts';
import { formatUnits } from 'viem';

type PairType = 'WETH/USDC' | 'USDC/WETH' | 'WETH/DAI';

interface PriceDisplayProps {
    className?: string;
}

export function PriceDisplay({ className = '' }: PriceDisplayProps) {
    const [selectedPair, setSelectedPair] = useState<PairType>('WETH/USDC');

    // Get pair configuration
    const pairConfig = {
        'WETH/USDC': { tokenA: CONTRACTS.weth, tokenB: CONTRACTS.usdc, label: 'WETH / USDC' },
        'USDC/WETH': { tokenA: CONTRACTS.usdc, tokenB: CONTRACTS.weth, label: 'USDC / WETH' },
        'WETH/DAI': { tokenA: CONTRACTS.weth, tokenB: CONTRACTS.dai, label: 'WETH / DAI' },
    };

    const currentPair = pairConfig[selectedPair];
    const { priceInfo, isLoading, error } = usePoolPrice(currentPair.tokenA, currentPair.tokenB);

    // Format price for display
    const displayPrice = priceInfo?.price
        ? priceInfo.price >= 1
            ? priceInfo.price.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 4 })
            : priceInfo.price.toFixed(8)
        : '—';

    // Price change indicator
    const priceChange = priceInfo?.change24h ?? 0;
    const isPositive = priceChange >= 0;

    return (
        <GlassCard className={`h-[460px] flex flex-col ${className}`}>
            {/* Header */}
            <div className="flex-between mb-4">
                <div className="flex items-center gap-4">
                    <h3 className="font-semibold text-lg">Pool Price</h3>
                    <div className="flex items-center gap-2 text-xs font-medium">
                        <span className="w-2 h-2 rounded-full bg-[var(--color-success)] animate-pulse"></span>
                        <span className="text-[var(--color-text-secondary)]">Live</span>
                    </div>
                </div>
                {/* Pair Selector */}
                <div className="flex gap-2">
                    {(Object.keys(pairConfig) as PairType[]).map((pair) => (
                        <button
                            key={pair}
                            onClick={() => setSelectedPair(pair)}
                            className={`px-2 py-1 rounded-md text-xs transition-colors ${
                                selectedPair === pair
                                    ? 'bg-[var(--color-primary)] text-white'
                                    : 'glass-interactive'
                            }`}
                        >
                            {pair}
                        </button>
                    ))}
                </div>
            </div>

            {/* Main Price Display */}
            <div className="flex-1 flex flex-col items-center justify-center border-t border-white/5 pt-6 bg-gradient-to-b from-transparent to-white/5 rounded-b-2xl">
                {isLoading ? (
                    <div className="flex items-center gap-3">
                        <div className="w-6 h-6 border-2 border-[var(--color-primary)] border-t-transparent rounded-full animate-spin" />
                        <span className="text-[var(--color-text-secondary)]">Loading price...</span>
                    </div>
                ) : error ? (
                    <div className="text-[var(--color-warning)]">{error}</div>
                ) : (
                    <>
                        {/* Pair Label */}
                        <div className="text-sm text-[var(--color-text-secondary)] mb-2">
                            {currentPair.label}
                        </div>

                        {/* Price */}
                        <div className="text-5xl font-bold mb-2 font-mono">
                            {displayPrice}
                        </div>

                        {/* Change Indicator */}
                        {priceChange !== 0 && (
                            <div className={`text-sm font-medium mb-4 ${isPositive ? 'text-[var(--color-success)]' : 'text-[var(--color-error)]'}`}>
                                {isPositive ? '↑' : '↓'} {Math.abs(priceChange).toFixed(4)}% (last swap)
                            </div>
                        )}

                        {/* Reserves Info */}
                        <div className="mt-6 w-full max-w-sm space-y-3">
                            <div className="text-xs text-[var(--color-text-secondary)] text-center mb-2">
                                Pool Reserves
                            </div>
                            <div className="flex justify-between items-center px-4 py-2 glass-subtle rounded-lg">
                                <span className="text-sm text-[var(--color-text-secondary)]">{priceInfo?.token0Symbol}</span>
                                <span className="font-mono text-sm">
                                    {priceInfo?.reserve0
                                        ? parseFloat(priceInfo.reserve0).toLocaleString(undefined, { maximumFractionDigits: 4 })
                                        : '—'}
                                </span>
                            </div>
                            <div className="flex justify-between items-center px-4 py-2 glass-subtle rounded-lg">
                                <span className="text-sm text-[var(--color-text-secondary)]">{priceInfo?.token1Symbol}</span>
                                <span className="font-mono text-sm">
                                    {priceInfo?.reserve1
                                        ? parseFloat(priceInfo.reserve1).toLocaleString(undefined, { maximumFractionDigits: 4 })
                                        : '—'}
                                </span>
                            </div>
                        </div>

                        {/* Last Update */}
                        <div className="mt-4 text-xs text-[var(--color-text-tertiary)]">
                            Updates on each new block
                        </div>
                    </>
                )}
            </div>
        </GlassCard>
    );
}
