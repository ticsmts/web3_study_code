'use client';

import { useState, useRef, useEffect } from 'react';

interface Token {
    symbol: string;
    name: string;
    address: string;
    logoUrl?: string;
    balance?: string;
}

interface TokenSelectProps {
    value?: Token;
    onChange: (token: Token) => void;
    tokens: Token[];
    label?: string;
    disabled?: boolean;
}

export function TokenSelect({
    value,
    onChange,
    tokens,
    label,
    disabled = false,
}: TokenSelectProps) {
    const [isOpen, setIsOpen] = useState(false);
    const [search, setSearch] = useState('');
    const dropdownRef = useRef<HTMLDivElement>(null);

    // Close on outside click
    useEffect(() => {
        function handleClickOutside(event: MouseEvent) {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setIsOpen(false);
            }
        }
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const filteredTokens = tokens.filter(
        (token) =>
            token.symbol.toLowerCase().includes(search.toLowerCase()) ||
            token.name.toLowerCase().includes(search.toLowerCase())
    );

    return (
        <div ref={dropdownRef} className="relative">
            {label && (
                <label className="block text-caption mb-2">{label}</label>
            )}

            <button
                type="button"
                onClick={() => !disabled && setIsOpen(!isOpen)}
                disabled={disabled}
                className={`
                    glass-interactive flex items-center gap-2 px-3 py-2 rounded-2xl
                    border border-[var(--border-color-subtle)] bg-[var(--glass-bg-secondary)]
                    hover:bg-[var(--glass-bg-hover)] transition-all
                    ${disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}
                `}
            >
                {value ? (
                    <>
                        <TokenLogo token={value} size={24} />
                        <span className="font-bold text-sm sm:text-base">{value.symbol}</span>
                        <ChevronIcon isOpen={isOpen} />
                    </>
                ) : (
                    <>
                        <div className="w-6 h-6 rounded-full bg-[var(--color-primary)]/20 animate-pulse" />
                        <span className="text-[var(--color-text-secondary)] font-medium">Select</span>
                        <ChevronIcon isOpen={isOpen} />
                    </>
                )}
            </button>

            {/* Dropdown */}
            {isOpen && (
                <div className="absolute z-[100] top-full mt-2 right-0 min-w-[280px] sm:min-w-[320px] 
                    bg-[#1c1d29] border border-[var(--border-color-strong)] rounded-2xl
                    animate-scale-in overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.5)] ring-1 ring-white/10">
                    {/* Search */}
                    <div className="p-3 border-b border-white/5 bg-white/5">
                        <input
                            type="text"
                            placeholder="Search by name or symbol..."
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                            className="w-full bg-black/40 border border-white/10 
                         rounded-xl px-4 py-2 text-sm focus:outline-none focus:border-[var(--color-primary)]/50
                         placeholder:text-[var(--color-text-tertiary)]"
                            autoFocus
                        />
                    </div>

                    {/* Token List */}
                    <div className="max-h-[350px] overflow-y-auto p-2 scrollbar-thin">
                        {filteredTokens.length === 0 ? (
                            <div className="text-center py-6 text-caption text-[var(--color-text-tertiary)]">No tokens found</div>
                        ) : (
                            filteredTokens.map((token) => (
                                <button
                                    key={token.address}
                                    onClick={() => {
                                        onChange(token);
                                        setIsOpen(false);
                                        setSearch('');
                                    }}
                                    className={`
                                        w-full flex items-center gap-3 p-3 rounded-xl
                                        transition-colors duration-150 group
                                        hover:bg-white/5
                                        ${value?.address === token.address ? 'bg-white/10 ring-1 ring-[var(--color-primary)]/40' : ''}
                                    `}
                                >
                                    <TokenLogo token={token} size={36} />
                                    <div className="flex-1 text-left">
                                        <div className="font-bold text-base text-white group-hover:text-[var(--color-primary)] transition-colors">{token.symbol}</div>
                                        <div className="text-[10px] text-[var(--color-text-tertiary)] uppercase tracking-widest font-medium">{token.name}</div>
                                    </div>
                                    {token.balance && (
                                        <div className="text-right">
                                            <div className="font-mono text-sm font-bold text-white/90">{token.balance}</div>
                                            <div className="text-[10px] text-[var(--color-text-tertiary)]">Balance</div>
                                        </div>
                                    )}
                                </button>
                            ))
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}

function TokenLogo({ token, size }: { token: Token; size: number }) {
    const initials = token.symbol.slice(0, 2).toUpperCase();

    if (token.logoUrl) {
        return (
            // eslint-disable-next-line @next/next/no-img-element
            <img
                src={token.logoUrl}
                alt={token.symbol}
                width={size}
                height={size}
                className="rounded-full"
            />
        );
    }

    // Fallback to initials
    return (
        <div
            className="rounded-full bg-[var(--color-primary)] flex items-center justify-center text-white font-bold"
            style={{ width: size, height: size, fontSize: size * 0.4 }}
        >
            {initials}
        </div>
    );
}

function ChevronIcon({ isOpen }: { isOpen: boolean }) {
    return (
        <svg
            className={`w-4 h-4 ml-auto transition-transform ${isOpen ? 'rotate-180' : ''}`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
        >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
    );
}

export type { Token };
