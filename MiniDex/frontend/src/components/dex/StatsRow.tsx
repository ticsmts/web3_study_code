'use client';

import { GlassCard } from '../ui/GlassCard';

interface StatItemProps {
    label: string;
    value: string;
    change?: string;
    changeType?: 'positive' | 'negative' | 'neutral';
}

function StatItem({ label, value, change, changeType = 'neutral' }: StatItemProps) {
    const changeColors = {
        positive: 'text-[var(--color-success)]',
        negative: 'text-[var(--color-error)]',
        neutral: 'text-[var(--color-text-tertiary)]',
    };

    return (
        <div className="text-center p-3 rounded-2xl glass-interactive cursor-default transition-all duration-300">
            <div className="text-caption text-[var(--color-text-secondary)] mb-1">{label}</div>
            <div className="text-2xl sm:text-number font-semibold">{value}</div>
            {change && (
                <div className={`text-sm ${changeColors[changeType]}`}>
                    {changeType === 'positive' && '+'}
                    {change}
                </div>
            )}
        </div>
    );
}

interface StatsRowProps {
    className?: string;
}

export function StatsRow({ className = '' }: StatsRowProps) {
    // Mock stats
    const stats = [
        { label: 'Total Value Locked', value: '$1.2M', change: '5.4%', changeType: 'positive' as const },
        { label: '24h Volume', value: '$340K', change: '12.8%', changeType: 'positive' as const },
        { label: '24h Fees', value: '$1,020', change: '8.2%', changeType: 'positive' as const },
        { label: 'Fee APR', value: '18.5%', change: '-2.1%', changeType: 'negative' as const },
    ];

    return (
        <GlassCard padding="none" className={`${className} bg-transparent border-none shadow-none`}>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-8">
                {stats.map((stat) => (
                    <StatItem key={stat.label} {...stat} />
                ))}
            </div>
        </GlassCard>
    );
}
