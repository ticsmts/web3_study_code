'use client';

import { CSSProperties } from 'react';
import { GlassCard } from '../ui/GlassCard';
import { useSwapEvents, SwapEvent } from '@/hooks/useSwapEvents';

interface ActivityListProps {
    className?: string;
    style?: CSSProperties;
}

export function ActivityList({ className = '', style }: ActivityListProps) {
    const { events, isLoading } = useSwapEvents(10);

    return (
        <GlassCard padding="none" className={className} style={style}>
            <div className="p-4 border-b border-[var(--border-color)] flex items-center justify-between">
                <h3 className="font-semibold flex items-center gap-2">
                    Recent Activity
                    {isLoading && (
                        <div className="w-3 h-3 border-2 border-[var(--color-primary)] border-t-transparent rounded-full animate-spin" />
                    )}
                </h3>
                <span className="text-xs text-[var(--color-text-tertiary)]">
                    {events.length} swap{events.length !== 1 ? 's' : ''}
                </span>
            </div>
            <div className="divide-y divide-[var(--border-color-subtle)] max-h-[400px] overflow-y-auto">
                {events.length === 0 && !isLoading ? (
                    <div className="p-8 text-center text-[var(--color-text-secondary)] text-sm">
                        No swap activity yet. Make a swap to see it here!
                    </div>
                ) : (
                    events.map((event) => (
                        <ActivityItem key={event.id} event={event} />
                    ))
                )}
            </div>
        </GlassCard>
    );
}

function ActivityItem({ event }: { event: SwapEvent }) {
    const shortAddress = `${event.to.slice(0, 6)}...${event.to.slice(-4)}`;
    const shortTxHash = `${event.txHash.slice(0, 10)}...`;

    return (
        <div className="p-4 hover:bg-[var(--glass-bg-secondary)] transition-colors">
            <div className="flex-between mb-1">
                <span className="text-sm font-medium text-[var(--color-primary)]">
                    Swap
                </span>
                <span className="text-caption text-[var(--color-text-tertiary)]">
                    Block #{event.blockNumber.toString()}
                </span>
            </div>
            <div className="flex items-center gap-2 text-sm">
                <span className="font-mono">{event.amountIn} {event.tokenIn}</span>
                <span className="text-[var(--color-text-tertiary)]">→</span>
                <span className="font-mono text-[var(--color-success)]">{event.amountOut} {event.tokenOut}</span>
            </div>
            <div className="flex items-center justify-between text-caption text-[var(--color-text-tertiary)] mt-1">
                <span>{shortAddress}</span>
                <span className="font-mono text-xs">{shortTxHash}</span>
            </div>
        </div>
    );
}
