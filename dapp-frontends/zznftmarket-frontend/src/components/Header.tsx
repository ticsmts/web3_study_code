import { AppKitButton } from "@reown/appkit/react";
import { useAccount } from "wagmi";

export default function Header() {
  const { address, isConnected } = useAccount();

  return (
    <div className="sticky top-0 z-10 border-b bg-white/80 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
        <div className="flex items-center gap-3">
          <div className="h-9 w-9 rounded-xl bg-gradient-to-br from-indigo-500 to-fuchsia-500" />
          <div>
            <div className="text-lg font-semibold leading-tight">ZZ NFT Market</div>
            <div className="text-xs text-zinc-500">
              {isConnected ? `Connected: ${address}` : "Not connected"}
            </div>
          </div>
        </div>

        {/* AppKit 官方组件：自动提供 Injected + WalletConnect 等连接方式 */}
        <AppKitButton />
      </div>
    </div>
  );
}
