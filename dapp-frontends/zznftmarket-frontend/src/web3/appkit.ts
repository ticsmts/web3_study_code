import { createAppKit } from "@reown/appkit/react";
import { WagmiAdapter } from "@reown/appkit-adapter-wagmi";
import { sepolia } from "@reown/appkit/networks";
import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient();

const projectId = import.meta.env.VITE_REOWN_PROJECT_ID as string;
if (!projectId) throw new Error("Missing VITE_REOWN_PROJECT_ID in .env.local");

export const networks = [sepolia];

export const wagmiAdapter = new WagmiAdapter({
  networks,
  projectId,
  ssr: false,
});

// ⚠️ 重要：createAppKit 必须在 React 组件外执行，避免重复初始化
createAppKit({
  adapters: [wagmiAdapter],
  networks,
  projectId,
  metadata: {
    name: "ZZ NFT Market",
    description: "ZZNFTMarketV2 Frontend",
    url: window.location.origin,
    icons: ["https://avatars.githubusercontent.com/u/179229932"],
  },
  features: {
    analytics: true,
  },
});
