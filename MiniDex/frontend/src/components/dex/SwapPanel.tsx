'use client';

import { useState, useEffect } from 'react';
import { GlassCard } from '../ui/GlassCard';
import { GlassButton } from '../ui/GlassButton';
import { TokenSelect, Token } from '../ui/TokenSelect';
import { AmountInput } from '../ui/AmountInput';
import { useTokenBalance } from '@/hooks/useTokenBalance';
import { useQuote } from '@/hooks/useQuote';
import { useSwap } from '@/hooks/useSwap';
import { TOKENS, CONTRACTS } from '@/lib/contracts';
import { Address, formatUnits } from 'viem';
import { usePublicClient } from 'wagmi';

// Map TOKENS from contracts.ts to Token interface for TokenSelect
const UI_TOKENS: Token[] = TOKENS.map(t => ({
    symbol: t.symbol,
    name: t.name,
    address: t.address,
    logoUrl: t.logoUrl,
}));

interface SwapPanelProps {
    className?: string;
}

export function SwapPanel({ className = '' }: SwapPanelProps) {
    const [fromToken, setFromToken] = useState<Token | undefined>(UI_TOKENS[1]); // USDC
    const [toToken, setToToken] = useState<Token | undefined>(UI_TOKENS[0]); // WETH
    const [fromAmount, setFromAmount] = useState('');
    const [toAmount, setToAmount] = useState('');
    const [slippage, setSlippage] = useState('0.5');
    const [showSettings, setShowSettings] = useState(false);
    const [isSwapping, setIsSwapping] = useState(false);

    // Hooks for real data
    const publicClient = usePublicClient();
    const { formattedBalance: fromBalance, refetch: refetchFromBalance } = useTokenBalance(fromToken?.address as Address);
    const { formattedBalance: toBalance, refetch: refetchToBalance } = useTokenBalance(toToken?.address as Address);
    const { formattedAmountOut, isLoading: isQuoteLoading } = useQuote(fromAmount, fromToken?.address as Address, toToken?.address as Address);
    const { swap } = useSwap();

    // Update toAmount when quote changes
    useEffect(() => {
        if (formattedAmountOut) {
            setToAmount(formattedAmountOut);
        } else if (!fromAmount) {
            setToAmount('');
        }
    }, [formattedAmountOut, fromAmount]);

    const handleSwapTokens = () => {
        const temp = fromToken;
        setFromToken(toToken);
        setToToken(temp);
        setFromAmount(toAmount);
        // toAmount will be updated by quote hook
    };

    const onSwap = async () => {
        if (!fromToken || !toToken || !fromAmount || !toAmount) return;

        setIsSwapping(true);
        try {
            // Calculate min amount out based on slippage
            const slippageMulti = 1 - parseFloat(slippage) / 100;
            const amountOutMin = (parseFloat(toAmount) * slippageMulti).toFixed(18);

            const txHash = await swap(
                fromAmount,
                amountOutMin,
                fromToken.address as Address,
                toToken.address as Address
            );
            console.log('Swap transaction submitted:', txHash);

            // Wait for transaction to be mined, then refetch balances
            if (publicClient && txHash) {
                await publicClient.waitForTransactionReceipt({ hash: txHash });
                refetchFromBalance();
                refetchToBalance();
            }

            setFromAmount('');
        } catch (error) {
            console.error('Swap failed:', error);
            alert('Swap failed. Check console for details.');
        } finally {
            setIsSwapping(false);
        }
    };

    const priceImpact = fromAmount && parseFloat(fromAmount) > 1000 ? '0.15' : '0.05';

    return (
        <GlassCard variant="elevated" padding="lg" className={`w-full ${className} overflow-visible`}>
            {/* Header */}
            <div className="flex-between mb-4">
                <h2 className="text-h3">Swap</h2>
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
                <div className="mb-4 p-4 glass-subtle rounded-xl animate-slide-up">
                    <div className="text-caption mb-2">Slippage Tolerance</div>
                    <div className="flex gap-2">
                        {['0.1', '0.5', '1.0'].map((value) => (
                            <button
                                key={value}
                                onClick={() => setSlippage(value)}
                                className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors
                  ${slippage === value
                                        ? 'bg-[var(--color-primary)] text-white'
                                        : 'glass-interactive'
                                    }`}
                            >
                                {value}%
                            </button>
                        ))}
                        <input
                            type="text"
                            value={slippage}
                            onChange={(e) => setSlippage(e.target.value)}
                            className="w-16 px-2 py-1.5 rounded-lg text-sm text-center glass border border-[var(--border-color)]"
                            placeholder="Custom"
                        />
                    </div>
                </div>
            )}

            {/* From Token */}
            <div className="space-y-4">
                <div className="relative">
                    <AmountInput
                        value={fromAmount}
                        onChange={(val) => setFromAmount(val)}
                        balance={fromBalance}
                        onMaxClick={() => setFromAmount(fromBalance)}
                        usdValue={fromAmount ? fromAmount : undefined}
                        tokenSelect={
                            <TokenSelect
                                value={fromToken}
                                onChange={setFromToken}
                                tokens={UI_TOKENS.filter(t => t.address !== toToken?.address)}
                            />
                        }
                    />
                </div>

                {/* Swap Direction Button */}
                <div className="flex justify-center -my-6 relative z-10">
                    <button
                        onClick={handleSwapTokens}
                        className="w-12 h-12 rounded-2xl glass-elevated flex-center
                         hover:bg-[var(--glass-bg-hover)] transition-all
                         hover:rotate-180 duration-300 shadow-xl border-2 border-[var(--border-color-strong)]"
                        aria-label="Swap tokens"
                    >
                        <SwapIcon />
                    </button>
                </div>

                {/* To Token */}
                <div className="relative">
                    <AmountInput
                        value={toAmount}
                        onChange={setToAmount}
                        placeholder="0.0"
                        disabled
                        usdValue={toAmount ? (parseFloat(toAmount) * 2200).toFixed(2) : undefined}
                        loading={isQuoteLoading}
                        tokenSelect={
                            <TokenSelect
                                value={toToken}
                                onChange={setToToken}
                                tokens={UI_TOKENS.filter(t => t.address !== fromToken?.address)}
                            />
                        }
                    />
                </div>
            </div>

            {/* Price Info */}
            {fromAmount && toAmount && (
                <div className="space-y-2 my-5 px-1 text-caption">
                    <div className="flex-between">
                        <span className="text-[var(--color-text-secondary)] font-medium">Rate</span>
                        <span className="font-semibold">1 {fromToken?.symbol} = {(parseFloat(toAmount) / parseFloat(fromAmount)).toFixed(6)} {toToken?.symbol}</span>
                    </div>
                    <div className="flex-between">
                        <span className="text-[var(--color-text-secondary)] font-medium">Price Impact</span>
                        <span className={`font-semibold ${parseFloat(priceImpact) > 0.1 ? 'text-[var(--color-warning)]' : 'text-green-400'}`}>
                            {priceImpact}%
                        </span>
                    </div>
                    <div className="flex-between">
                        <span className="text-[var(--color-text-secondary)] font-medium">Network Fee</span>
                        <span className="opacity-80">~$0.50</span>
                    </div>
                </div>
            )}

            {/* Route */}
            {fromToken && toToken && fromAmount && (
                <div className="mb-6 p-4 glass-subtle rounded-2xl border border-[var(--border-color-subtle)]">
                    <div className="text-[10px] text-[var(--color-text-tertiary)] uppercase tracking-widest font-bold mb-3">Route</div>
                    <div className="flex items-center gap-3 text-sm">
                        <div className="flex items-center gap-2 px-2 py-1 rounded-lg bg-[var(--glass-bg-secondary)] border border-[var(--border-color)]">
                            <span className="font-bold">{fromToken.symbol}</span>
                        </div>
                        <ArrowIcon />
                        <div className="flex items-center gap-2 px-2 py-1 rounded-lg bg-[var(--glass-bg-secondary)] border border-[var(--border-color)]">
                            <span className="font-bold">{toToken.symbol}</span>
                        </div>
                        <span className="ml-auto text-[10px] bg-green-500/10 text-green-400 px-2 py-0.5 rounded-full font-bold uppercase tracking-tighter border border-green-500/20">Best price</span>
                    </div>
                </div>
            )}

            {/* Swap Button */}
            <GlassButton
                variant="primary"
                size="lg"
                fullWidth
                disabled={!fromAmount || !toAmount || isSwapping}
                onClick={onSwap}
                loading={isSwapping}
                className="mt-4 h-14 text-lg font-bold rounded-2xl shadow-[0_8px_30px_rgb(99,102,241,0.2)]"
            >
                {!fromToken || !toToken
                    ? 'Select tokens'
                    : !fromAmount
                        ? 'Enter amount'
                        : isSwapping
                            ? 'Swapping...'
                            : 'Swap'}
            </GlassButton>
        </GlassCard>
    );
}

// Icons
function SettingsIcon() {
    return (
        <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37-2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
        </svg>
    );
}

function SwapIcon() {
    return (
        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
        </svg>
    );
}

function ArrowIcon() {
    return (
        <svg className="w-4 h-4 text-[var(--color-text-tertiary)]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M14 5l7 7m0 0l-7 7m7-7H3" />
        </svg>
    );
}
