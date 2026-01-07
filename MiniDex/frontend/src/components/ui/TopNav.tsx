'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import Link from 'next/link';

export function TopNav() {
    return (
        <header className="fixed top-0 left-0 right-0 z-50 glass border-b border-[var(--border-color)]">
            <div className="max-w-7xl mx-auto px-4 h-16 flex-between">
                {/* Logo */}
                <Link href="/" className="flex items-center gap-2 font-bold text-xl min-w-fit pr-2">
                    <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-[var(--color-primary)] to-[var(--color-secondary)] flex-center">
                        <span className="text-white text-sm">M</span>
                    </div>
                    <span className="hidden sm:inline">MiniDex</span>
                </Link>

                {/* Navigation Links */}
                <nav className="hidden md:flex items-center gap-1">
                    <NavLink href="/" active>Swap</NavLink>
                    <NavLink href="/pool">Pool</NavLink>
                    <NavLink href="/stats">Stats</NavLink>
                </nav>

                {/* Wallet Connect */}
                <div className="flex items-center gap-3">
                    <ConnectButton.Custom>
                        {({
                            account,
                            chain,
                            openAccountModal,
                            openChainModal,
                            openConnectModal,
                            mounted,
                        }) => {
                            const ready = mounted;
                            const connected = ready && account && chain;

                            return (
                                <div
                                    {...(!ready && {
                                        'aria-hidden': true,
                                        style: {
                                            opacity: 0,
                                            pointerEvents: 'none',
                                            userSelect: 'none',
                                        },
                                    })}
                                >
                                    {!connected ? (
                                        <button
                                            onClick={openConnectModal}
                                            className="glass glass-interactive px-4 py-2 rounded-xl font-medium"
                                        >
                                            Connect Wallet
                                        </button>
                                    ) : chain.unsupported ? (
                                        <button
                                            onClick={openChainModal}
                                            className="px-4 py-2 rounded-xl font-medium bg-[var(--color-error)] text-white"
                                        >
                                            Wrong Network
                                        </button>
                                    ) : (
                                        <div className="flex items-center gap-2">
                                            <button
                                                onClick={openChainModal}
                                                className="glass glass-interactive px-3 py-2 rounded-xl text-sm flex items-center gap-2"
                                            >
                                                {chain.hasIcon && chain.iconUrl && (
                                                    // eslint-disable-next-line @next/next/no-img-element
                                                    <img
                                                        alt={chain.name ?? 'Chain icon'}
                                                        src={chain.iconUrl}
                                                        className="w-4 h-4 rounded-full"
                                                    />
                                                )}
                                                <span className="hidden sm:inline">{chain.name}</span>
                                            </button>
                                            <button
                                                onClick={openAccountModal}
                                                className="glass glass-interactive px-4 py-2 rounded-xl font-medium"
                                            >
                                                {account.displayName}
                                            </button>
                                        </div>
                                    )}
                                </div>
                            );
                        }}
                    </ConnectButton.Custom>
                </div>
            </div>
        </header>
    );
}

function NavLink({ href, children, active = false }: { href: string; children: React.ReactNode; active?: boolean }) {
    return (
        <Link
            href={href}
            className={`
                px-4 py-2 rounded-xl font-medium transition-all duration-300
                ${active
                    ? 'bg-[var(--glass-bg-hover)] text-[var(--color-text-primary)] shadow-sm'
                    : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-[var(--glass-bg-hover)] hover:scale-105 active:scale-95'
                }
            `}
        >
            {children}
        </Link>
    );
}
