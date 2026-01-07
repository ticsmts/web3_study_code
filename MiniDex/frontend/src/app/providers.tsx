'use client';

import { getDefaultConfig, RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import { mainnet, anvil } from 'wagmi/chains';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import '@rainbow-me/rainbowkit/styles.css';

// Configure wagmi
const config = getDefaultConfig({
    appName: 'MiniDex',
    projectId: 'minidex-local', // Replace with WalletConnect project ID for production
    chains: [anvil, mainnet],
    ssr: true,
});

// Create query client
const queryClient = new QueryClient();

// Custom RainbowKit theme matching our glassmorphism
const customTheme = darkTheme({
    accentColor: '#6366f1',
    accentColorForeground: 'white',
    borderRadius: 'large',
    fontStack: 'system',
    overlayBlur: 'small',
});

export function Providers({ children }: { children: React.ReactNode }) {
    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClient}>
                <RainbowKitProvider theme={customTheme}>
                    {children}
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
}
