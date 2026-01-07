'use client';

import { ChangeEvent, useCallback } from 'react';

interface AmountInputProps {
    value: string;
    onChange: (value: string) => void;
    placeholder?: string;
    disabled?: boolean;
    label?: string;
    balance?: string;
    onMaxClick?: () => void;
    usdValue?: string;
    loading?: boolean;
    tokenSelect?: React.ReactNode;
}

export function AmountInput({
    value,
    onChange,
    placeholder = '0.0',
    disabled = false,
    label,
    balance,
    onMaxClick,
    usdValue,
    loading = false,
    tokenSelect,
}: AmountInputProps) {
    const handleChange = useCallback(
        (e: ChangeEvent<HTMLInputElement>) => {
            const inputValue = e.target.value;
            // Allow only numbers and one decimal point
            if (/^[0-9]*\.?[0-9]*$/.test(inputValue) || inputValue === '') {
                onChange(inputValue);
            }
        },
        [onChange]
    );

    return (
        <div className="space-y-2">
            {/* Label Row */}
            {label && (
                <div className="flex mb-1">
                    <span className="text-caption">{label}</span>
                </div>
            )}

            {/* Input Container */}
            <div className={`relative bg-[var(--glass-bg-secondary)] rounded-2xl p-4 border border-transparent 
                focus-within:border-[var(--color-primary)] transition-all overflow-visible`}>
                <div className="flex items-center justify-between gap-4">
                    <div className="flex-1 min-w-0">
                        {loading ? (
                            <div className="flex items-center h-10">
                                <div className="w-5 h-5 border-2 border-[var(--color-primary)] border-t-transparent rounded-full animate-spin mr-2" />
                            </div>
                        ) : (
                            <input
                                type="text"
                                inputMode="decimal"
                                autoComplete="off"
                                autoComplete-="false"
                                pattern="^[0-9]*[.,]?[0-9]*$"
                                value={value}
                                onChange={handleChange}
                                placeholder={placeholder}
                                disabled={disabled}
                                className={`
                                    w-full bg-transparent
                                    text-2xl sm:text-3xl font-bold text-left
                                    placeholder:text-[var(--color-text-muted)]
                                    disabled:opacity-50 disabled:cursor-not-allowed
                                    focus:outline-none
                                `}
                            />
                        )}
                        <div className="text-xs text-[var(--color-text-tertiary)] mt-1">
                            {usdValue ? `≈ $${usdValue}` : '\u00A0'}
                        </div>
                    </div>

                    {/* Token Selection Slot */}
                    {tokenSelect && (
                        <div className="flex-shrink-0">
                            {tokenSelect}
                        </div>
                    )}
                </div>

                {/* Info Row: Balance & Max */}
                <div className="flex justify-end items-center mt-3 pt-2 border-t border-[var(--border-color-subtle)]">
                    <div className="flex items-center gap-2">
                        {balance && (
                            <span className="text-[10px] sm:text-xs text-[var(--color-text-secondary)]">
                                Balance: <span className="font-mono">{balance}</span>
                            </span>
                        )}
                        {onMaxClick && balance && (
                            <button
                                type="button"
                                onClick={onMaxClick}
                                className="px-1.5 py-0.5 rounded bg-[var(--color-primary)]/10 text-[10px] font-bold text-[var(--color-primary)] 
                                     hover:bg-[var(--color-primary)]/20 transition-all uppercase"
                            >
                                MAX
                            </button>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
