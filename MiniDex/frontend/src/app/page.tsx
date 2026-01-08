'use client';

import { useState } from 'react';
import { TopNav } from '@/components/ui/TopNav';
import { SwapPanel } from '@/components/dex/SwapPanel';
import { LiquidityPanel } from '@/components/dex/LiquidityPanel';
import { StatsRow } from '@/components/dex/StatsRow';
import { ActivityList } from '@/components/dex/ActivityList';
import { BalancePanel } from '@/components/dex/BalancePanel';
import { PriceDisplay } from '@/components/dex/PriceDisplay';

type TabType = 'swap' | 'liquidity';

export default function Home() {
  const [activeTab, setActiveTab] = useState<TabType>('swap');

  return (
    <div className="min-h-screen flex flex-col">
      {/* Fixed Navigation Bar */}
      <TopNav />

      {/* Main Content Area */}
      <main className="flex-1 pt-20">
        {/* Content Container */}
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pb-12">
          {/* Stats Row */}
          <div className="mb-10">
            <StatsRow />
          </div>

          {/* Main Dashboard Layout */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
            {/* Left Column: Price & Activity (7 Columns) */}
            <div className="lg:col-span-12 xl:col-span-7 space-y-6">
              {/* Real-time Pool Price */}
              <PriceDisplay />

              {/* Recent Activity */}
              <ActivityList />
            </div>

            {/* Right Column: Swap/Liquidity Sidebar (5 Columns) */}
            <div className="lg:col-span-12 xl:col-span-5 flex flex-col gap-6 sticky top-24">
              {/* Tab Navigation */}
              <div className="flex gap-2 p-1 glass rounded-2xl border border-[var(--border-color)]">
                <TabButton
                  active={activeTab === 'swap'}
                  onClick={() => setActiveTab('swap')}
                >
                  Swap
                </TabButton>
                <TabButton
                  active={activeTab === 'liquidity'}
                  onClick={() => setActiveTab('liquidity')}
                >
                  Liquidity
                </TabButton>
              </div>

              {/* Active Panel */}
              <div className="w-full">
                {activeTab === 'swap' ? <SwapPanel /> : <LiquidityPanel />}
              </div>

              {/* My Token Balances */}
              <BalancePanel />
            </div>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="py-6 text-center text-sm opacity-50">
        Built with ❤️ using Uniswap V2 • MiniDex
      </footer>
    </div>
  );
}

// Tab Button Component
function TabButton({
  children,
  active,
  onClick,
}: {
  children: React.ReactNode;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex-1 py-2.5 px-4 rounded-xl text-sm font-bold transition-all duration-200
        ${active
          ? 'bg-[var(--color-primary)] text-white shadow-[0_4px_20px_rgba(99,102,241,0.3)]'
          : 'text-[var(--color-text-secondary)] hover:text-white hover:bg-white/5'
        }`}
    >
      {children}
    </button>
  );
}
