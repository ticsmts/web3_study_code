import "../styles/globals.css";

import { useMemo } from "react";
import { WagmiProvider } from "wagmi";
import { getDefaultConfig, RainbowKitProvider, lightTheme } from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { sepolia, anvil } from "wagmi/chains";
import { http } from "viem";

const projectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || "";

const wagmiConfig = getDefaultConfig({
  appName: "StakingPool",
  projectId,
  chains: [sepolia, anvil],
  ssr: true,
  transports: {
    [sepolia.id]: http(process.env.NEXT_PUBLIC_SEPOLIA_RPC_URL || "https://rpc.sepolia.org"),
    [anvil.id]: http(process.env.NEXT_PUBLIC_ANVIL_RPC_URL || "http://127.0.0.1:8545")
  }
});

const queryClient = new QueryClient();

export default function App({ Component, pageProps }) {
  const theme = useMemo(
    () =>
      lightTheme({
        accentColor: "#ff8a3d",
        accentColorForeground: "#fff",
        borderRadius: "large"
      }),
    []
  );

  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider theme={theme} modalSize="compact">
          <Component {...pageProps} />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
