'use client';

import { TopNav } from '@/components/ui/TopNav';
import { SwapPanel } from '@/components/dex/SwapPanel';
import { StatsRow } from '@/components/dex/StatsRow';
import { ActivityList } from '@/components/dex/ActivityList';
import { BalancePanel } from '@/components/dex/BalancePanel';
import { PriceDisplay } from '@/components/dex/PriceDisplay';

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Fixed Navigation Bar */}
      <TopNav />

      {/* Spacer for fixed navbar - h-16 matches TopNav height */}
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

            {/* Right Column: Swap Sidebar (5 Columns) */}
            <div className="lg:col-span-12 xl:col-span-5 flex flex-col gap-6 sticky top-24">
              <div className="w-full">
                <SwapPanel />
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
