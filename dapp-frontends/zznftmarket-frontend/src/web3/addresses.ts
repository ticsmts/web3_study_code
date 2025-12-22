export const MARKET_ADDRESS = import.meta.env.VITE_MARKET_ADDRESS as `0x${string}`;
export const NFT_ADDRESS = import.meta.env.VITE_NFT_ADDRESS as `0x${string}`;
export const TOKEN_ADDRESS = import.meta.env.VITE_TOKEN_ADDRESS as `0x${string}`;

if (!MARKET_ADDRESS || !NFT_ADDRESS || !TOKEN_ADDRESS) {
  throw new Error("Missing contract addresses in .env.local");
}
