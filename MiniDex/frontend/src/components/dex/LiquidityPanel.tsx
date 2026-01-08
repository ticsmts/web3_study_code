'use client';

import { useState, useEffect } from 'react';
import { GlassCard } from '../ui/GlassCard';
import { GlassButton } from '../ui/GlassButton';
import { TokenSelect, Token } from '../ui/TokenSelect';
import { AmountInput } from '../ui/AmountInput';
import { useTokenBalance } from '@/hooks/useTokenBalance';
import { useAddLiquidity } from '@/hooks/useAddLiquidity';
import { useLiquidityQuote } from '@/hooks/useLiquidityQuote';
import { TOKENS } from '@/lib/contracts';
import { Address } from 'viem';
import { usePublicClient } from 'wagmi';

// Map TOKENS to Token interface
const UI_TOKENS: Token[] = TOKENS.map(t => ({
    symbol: t.symbol,
    name: t.name,
    address: t.address,
    logoUrl: t.logoUrl,
}));

interface LiquidityPanelProps {
    className?: string;
}

export function LiquidityPanel({ className = '' }: LiquidityPanelProps) {
    const [tokenA, setTokenA] = useState<Token | null>(UI_TOKENS[0] || null);
    const [tokenB, setTokenB] = useState<Token | null>(UI_TOKENS[1] || null);
    const [amountA, setAmountA] = useState('');
    const [amountB, setAmountB] = useState('');
    const [slippage, setSlippage] = useState('0.5');
    const [showSettings, setShowSettings] = useState(false);
    const [isAdding, setIsAdding] = useState(false);
    const [lastEdited, setLastEdited] = useState<'A' | 'B'>('A');

    const publicClient = usePublicClient();
    const { addLiquidity } = useAddLiquidity();

    // Token balances
    const { formattedBalance: balanceA, refetch: refetchBalanceA } = useTokenBalance(tokenA?.address as Address);
    const { formattedBalance: balanceB, refetch: refetchBalanceB } = useTokenBalance(tokenB?.address as Address);

    // Pool info and quote
    const { poolInfo, optimalAmountB, optimalAmountA, estimatedLPTokens, isLoading } = useLiquidityQuote(
        tokenA?.address as Address,
        tokenB?.address as Address,
        lastEdited === 'A' ? amountA : undefined,
        lastEdited === 'B' ? amountB : undefined
    );

    // 当 amountA 变化时，自动设置 amountB
    useEffect(() => {
        if (lastEdited === 'A' && optimalAmountB && poolInfo?.exists) {
            setAmountB(parseFloat(optimalAmountB).toFixed(6));
        }
    }, [optimalAmountB, lastEdited, poolInfo?.exists]);

    // 当 amountB 变化时，自动设置 amountA
    useEffect(() => {
        if (lastEdited === 'B' && optimalAmountA && poolInfo?.exists) {
            setAmountA(parseFloat(optimalAmountA).toFixed(6));
        }
    }, [optimalAmountA, lastEdited, poolInfo?.exists]);

    const handleAmountAChange = (value: string) => {
        setAmountA(value);
        setLastEdited('A');
    };

    const handleAmountBChange = (value: string) => {
        setAmountB(value);
        setLastEdited('B');
    };

    const onAddLiquidity = async () => {
        if (!tokenA || !tokenB || !amountA || !amountB) return;

        setIsAdding(true);
        try {
            const txHash = await addLiquidity(
                tokenA.address as Address,
                tokenB.address as Address,
                amountA,
                amountB,
                parseFloat(slippage)
            );
            console.log('Add liquidity tx:', txHash);

            // 等待交易确认
            if (publicClient && txHash) {
                await publicClient.waitForTransactionReceipt({ hash: txHash });
                refetchBalanceA();
                refetchBalanceB();
            }

            // 清空输入
            setAmountA('');
            setAmountB('');
        } catch (error) {
            console.error('Add liquidity failed:', error);
            alert('Add liquidity failed. Check console for details.');
        } finally {
            setIsAdding(false);
        }
    };

    const formatBalance = (balance: string) => {
        const num = parseFloat(balance);
        if (isNaN(num)) return '0';
        return num.toLocaleString(undefined, { maximumFractionDigits: 4 });
    };

    return (
        <GlassCard variant="elevated" padding="lg" className={`w-full ${className} overflow-visible`}>
            {/* Header */}
            <div className="flex-between mb-4">
                <h2 className="text-h3">Add Liquidity</h2>
                <button
                    onClick={() => setShowSettings(!showSettings)}
                    className="p-2 rounded-xl glass-interactive"
                    aria-label="Settings"
                >
                    <SettingsIcon />
                </button>
            </div>

            {/* Settings Panel */}
            {showSettings && (
                <div className="mb-4 p-4 glass-subtle rounded-xl border border-[var(--border-color)]">
                    <div className="text-sm font-medium mb-2">Slippage Tolerance</div>
                    <div className="flex gap-2">
                        {['0.1', '0.5', '1.0'].map((val) => (
                            <button
                                key={val}
                                onClick={() => setSlippage(val)}
                                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                                    slippage === val
                                        ? 'bg-[var(--color-primary)] text-white'
                                        : 'glass-interactive'
                                }`}
                            >
                                {val}%
                            </button>
                        ))}
                        <input
                            type="text"
                            value={slippage}
                            onChange={(e) => setSlippage(e.target.value)}
                            className="w-16 px-2 py-1.5 rounded-lg bg-[var(--glass-bg-secondary)] text-sm text-center focus:outline-none focus:ring-1 focus:ring-[var(--color-primary)]"
                            placeholder="Custom"
                        />
                    </div>
                </div>
            )}

            {/* Token A Input */}
            <div className="space-y-3">
                <div className="relative">
                    <AmountInput
                        value={amountA}
                        onChange={handleAmountAChange}
                        balance={formatBalance(balanceA)}
                        onMaxClick={() => handleAmountAChange(balanceA)}
                        tokenSelect={
                            <TokenSelect
                                value={tokenA}
                                onChange={setTokenA}
                                tokens={UI_TOKENS.filter(t => t.address !== tokenB?.address)}
                            />
                        }
                    />
                </div>

                {/* Plus Icon */}
                <div className="flex justify-center -my-1">
                    <div className="w-10 h-10 rounded-xl glass-elevated flex-center border border-[var(--border-color)]">
                        <PlusIcon />
                    </div>
                </div>

                {/* Token B Input */}
                <div className="relative">
                    <AmountInput
                        value={amountB}
                        onChange={handleAmountBChange}
                        balance={formatBalance(balanceB)}
                        onMaxClick={() => handleAmountBChange(balanceB)}
                        loading={isLoading}
                        tokenSelect={
                            <TokenSelect
                                value={tokenB}
                                onChange={setTokenB}
                                tokens={UI_TOKENS.filter(t => t.address !== tokenA?.address)}
                            />
                        }
                    />
                </div>
            </div>

            {/* Pool Info */}
            {tokenA && tokenB && (
                <div className="mt-5 p-4 glass-subtle rounded-2xl border border-[var(--border-color-subtle)]">
                    <div className="text-[10px] text-[var(--color-text-tertiary)] uppercase tracking-widest font-bold mb-3">
                        {poolInfo?.exists ? 'Pool Info' : 'New Pool'}
                    </div>

                    {poolInfo?.exists ? (
                        <div className="space-y-2 text-sm">
                            <div className="flex-between">
                                <span className="text-[var(--color-text-secondary)]">
                                    1 {tokenA.symbol} =
                                </span>
                                <span className="font-mono font-medium">
                                    {poolInfo.priceAperB} {tokenB.symbol}
                                </span>
                            </div>
                            <div className="flex-between">
                                <span className="text-[var(--color-text-secondary)]">
                                    1 {tokenB.symbol} =
                                </span>
                                <span className="font-mono font-medium">
                                    {poolInfo.priceBperA} {tokenA.symbol}
                                </span>
                            </div>
                            {estimatedLPTokens && parseFloat(estimatedLPTokens) > 0 && (
                                <>
                                    <div className="border-t border-[var(--border-color-subtle)] my-2" />
                                    <div className="flex-between">
                                        <span className="text-[var(--color-text-secondary)]">
                                            LP Tokens
                                        </span>
                                        <span className="font-mono font-medium text-[var(--color-primary)]">
                                            ~{parseFloat(estimatedLPTokens).toFixed(6)}
                                        </span>
                                    </div>
                                    <div className="flex-between">
                                        <span className="text-[var(--color-text-secondary)]">
                                            Share of Pool
                                        </span>
                                        <span className="font-mono font-medium text-green-400">
                                            {poolInfo.shareOfPool}%
                                        </span>
                                    </div>
                                </>
                            )}
                        </div>
                    ) : (
                        <div className="text-sm text-[var(--color-text-secondary)]">
                            <p className="mb-2">You are the first liquidity provider.</p>
                            <p>The ratio of tokens you add will set the price of this pool.</p>
                        </div>
                    )}
                </div>
            )}

            {/* Add Liquidity Button */}
            <GlassButton
                variant="primary"
                size="lg"
                fullWidth
                disabled={!amountA || !amountB || isAdding || parseFloat(amountA) <= 0 || parseFloat(amountB) <= 0}
                onClick={onAddLiquidity}
                loading={isAdding}
                className="mt-4 h-14 text-lg font-bold rounded-2xl shadow-[0_8px_30px_rgb(99,102,241,0.2)]"
            >
                {!tokenA || !tokenB
                    ? 'Select tokens'
                    : !amountA || !amountB
                        ? 'Enter amounts'
                        : isAdding
                            ? 'Adding...'
                            : poolInfo?.exists
                                ? 'Add Liquidity'
                                : 'Create Pool & Add Liquidity'}
            </GlassButton>
        </GlassCard>
    );
}

function SettingsIcon() {
    return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
    );
}

function PlusIcon() {
    return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
        </svg>
    );
}
