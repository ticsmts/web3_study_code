# StakingPool Frontend (Next.js)

Glassmorphism + Neumorphism UI with on-chain interaction via RainbowKit + wagmi + viem.

## Setup
```bash
cd frontend
npm install
```

## Environment
Create `.env.local`:
```
NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID=your_project_id
NEXT_PUBLIC_STAKING_POOL_ADDRESS=0x...
NEXT_PUBLIC_ZZ_TOKEN_ADDRESS=0x...
NEXT_PUBLIC_A_TOKEN_ADDRESS=0x...  # aWETH on your network
NEXT_PUBLIC_LENDING_POOL_ADDRESS=0x...  # mock lending pool on Anvil
NEXT_PUBLIC_WETH_ADDRESS=0x...          # mock WETH on Anvil
NEXT_PUBLIC_ANVIL_RPC_URL=http://127.0.0.1:8545
NEXT_PUBLIC_SEPOLIA_RPC_URL=https://rpc.sepolia.org
```

For Anvil mocks, you can auto-fill `.env.local` from the deploy output:
```
powershell -ExecutionPolicy Bypass -File ..\script\UpdateFrontendEnv.ps1
```

## Dev
```
npm run dev
```

## Notes
- If you use Anvil, deploy StakingPool locally and set its address in `.env.local`.
- For Anvil mocks, use the Mock aToken address printed by the deploy/flow script.
- RainbowKit requires a WalletConnect project id.
- `ZZ_TOKEN_ADDRESS` is optional, used only to display rewards balance.
- Recent Activity reads on-chain events from the last ~2000 blocks.
