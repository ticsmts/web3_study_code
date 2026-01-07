'use client';

import { ButtonHTMLAttributes, ReactNode } from 'react';

interface GlassButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
    children: ReactNode;
    variant?: 'primary' | 'secondary' | 'ghost';
    size?: 'sm' | 'md' | 'lg';
    fullWidth?: boolean;
    loading?: boolean;
}

export function GlassButton({
    children,
    variant = 'primary',
    size = 'md',
    fullWidth = false,
    loading = false,
    disabled,
    className = '',
    ...props
}: GlassButtonProps) {
    const baseStyles = `
    inline-flex items-center justify-center gap-2
    font-medium transition-all
    focus-ring
    disabled:opacity-50 disabled:cursor-not-allowed
  `;

    const sizeStyles = {
        sm: 'h-9 px-3 text-sm rounded-xl',
        md: 'h-11 px-4 text-base rounded-xl',
        lg: 'h-14 px-6 text-lg rounded-2xl',
    };

    const variantStyles = {
        primary: `
      bg-[var(--color-primary)] text-white
      hover:bg-[var(--color-primary-hover)]
      active:scale-[0.98]
      shadow-[0_4px_14px_rgba(99,102,241,0.3)]
      hover:shadow-[0_6px_25px_rgba(99,102,241,0.5)]
      transition-all duration-300
    `,
        secondary: `
      glass glass-interactive
      text-[var(--color-text-primary)]
    `,
        ghost: `
      bg-transparent
      text-[var(--color-text-secondary)]
      hover:text-[var(--color-text-primary)]
      hover:bg-[var(--glass-bg-hover)]
    `,
    };

    return (
        <button
            className={`
        ${baseStyles}
        ${sizeStyles[size]}
        ${variantStyles[variant]}
        ${fullWidth ? 'w-full' : ''}
        ${className}
      `}
            disabled={disabled || loading}
            {...props}
        >
            {loading ? (
                <>
                    <LoadingSpinner />
                    <span>Loading...</span>
                </>
            ) : (
                children
            )}
        </button>
    );
}

function LoadingSpinner() {
    return (
        <svg
            className="animate-spin h-4 w-4"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
        >
            <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
            />
            <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
        </svg>
    );
}
