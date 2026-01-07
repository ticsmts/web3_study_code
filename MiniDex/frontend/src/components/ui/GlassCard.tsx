'use client';

import { ReactNode, CSSProperties } from 'react';

interface GlassCardProps {
    children: ReactNode;
    className?: string;
    variant?: 'default' | 'elevated' | 'subtle';
    padding?: 'none' | 'sm' | 'md' | 'lg';
    interactive?: boolean;
    style?: CSSProperties;
}

const paddingMap = {
    none: '',
    sm: 'p-3',
    md: 'p-4',
    lg: 'p-6',
};

const variantMap = {
    default: 'glass',
    elevated: 'glass-elevated',
    subtle: 'glass-subtle',
};

export function GlassCard({
    children,
    className = '',
    variant = 'default',
    padding = 'md',
    interactive = false,
    style,
}: GlassCardProps) {
    return (
        <div
            className={`
        ${variantMap[variant]}
        ${paddingMap[padding]}
        ${interactive ? 'glass-interactive cursor-pointer' : ''}
        ${className}
      `}
            style={style}
        >
            {children}
        </div>
    );
}
