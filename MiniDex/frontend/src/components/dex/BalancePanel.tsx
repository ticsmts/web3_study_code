'use client';

import { GlassCard } from '../ui/GlassCard';
import { useTokenBalance } from '@/hooks/useTokenBalance';
import { TOKENS } from '@/lib/contracts';
import { useAccount } from 'wagmi';
import { Address } from 'viem';

interface TokenBalanceRowProps {
    symbol: string;
    name: string;
    address: Address;
}

function TokenBalanceRow({ symbol, name, address }: TokenBalanceRowProps) {
    const { formattedBalance, isLoading, refetch } = useTokenBalance(address);

    // Format balance to show max 6 decimal places
    const displayBalance = formattedBalance
        ? parseFloat(formattedBalance).toLocaleString(undefined, {
            minimumFractionDigits: 0,
            maximumFractionDigits: 6,
        })
        : '0';

    return (
        <div className="flex items-center justify-between py-3 border-b border-[var(--border-color-subtle)] last:border-b-0">
            <div className="flex items-center gap-3">
                {/* Token Icon Placeholder */}
                <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--color-primary)] to-[var(--color-secondary)] flex items-center justify-center text-white text-xs font-bold">
                    {symbol.slice(0, 2)}
                </div>
                <div>
                    <div className="font-medium text-sm">{symbol}</div>
                    <div className="text-xs text-[var(--color-text-tertiary)]">{name}</div>
                </div>
            </div>
            <div className="text-right">
                {isLoading ? (
                    <div className="w-4 h-4 border-2 border-[var(--color-primary)] border-t-transparent rounded-full animate-spin" />
                ) : (
                    <div className="font-mono text-sm font-medium">{displayBalance}</div>
                )}
            </div>
        </div>
    );
}

interface BalancePanelProps {
    className?: string;
}

export function BalancePanel({ className = '' }: BalancePanelProps) {
    const { address, isConnected } = useAccount();

    if (!isConnected) {
        return (
            <GlassCard padding="md" className={className}>
                <h4 className="text-sm font-semibold mb-3 flex items-center gap-2">
                    <WalletIcon />
                    My Balances
                </h4>
                <div className="text-center py-6 text-[var(--color-text-secondary)] text-sm">
                    Connect wallet to view balances
                </div>
            </GlassCard>
        );
    }

    return (
        <GlassCard padding="md" className={className}>
            <div className="flex items-center justify-between mb-4">
                <h4 className="text-sm font-semibold flex items-center gap-2">
                    <WalletIcon />
                    My Balances
                </h4>
                <div className="text-xs text-[var(--color-text-tertiary)] font-mono">
                    {address?.slice(0, 6)}...{address?.slice(-4)}
                </div>
            </div>

            <div className="space-y-0">
                {TOKENS.map((token) => (
                    <TokenBalanceRow
                        key={token.address}
                        symbol={token.symbol}
                        name={token.name}
                        address={token.address}
                    />
                ))}
            </div>

            {/* Refresh hint */}
            <div className="mt-4 pt-3 border-t border-[var(--border-color-subtle)]">
                <p className="text-xs text-[var(--color-text-tertiary)] text-center">
                    Balances update automatically after swaps
                </p>
            </div>
        </GlassCard>
    );
}

function WalletIcon() {
    return (
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
        </svg>
    );
}
