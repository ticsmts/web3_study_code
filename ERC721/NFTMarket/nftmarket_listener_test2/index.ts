import { createPublicClient, webSocket, parseAbiItem } from "viem";

const WS_URL = "ws://127.0.0.1:8545";
const MARKET = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

if (!MARKET) {
  throw new Error("Missing MARKET_ADDR env var");
}

const client = createPublicClient({
  transport: webSocket(WS_URL),
});

function now() {
  return new Date().toISOString();
}

async function main() {
  const block = await client.getBlockNumber();
  console.log(`[${now()}] ✅ listener booting...`);
  console.log(`[${now()}] 🔗 WS=${WS_URL}`);
  console.log(`[${now()}] 🏷️ MARKET=${MARKET}`);
  console.log(`[${now()}] 🧱 current block=${block}`);

  // Listed(listingId, seller, nft, tokenId, payToken, price)
  client.watchEvent({
    address: MARKET,
    event: parseAbiItem(
      "event Listed(uint256 indexed listingId, address indexed seller, address indexed nft, uint256 tokenId, address payToken, uint256 price)"
    ),
    onLogs: (logs) => {
      for (const l of logs) {
        const args = l.args as any;
        console.log(
          `[${now()}] 🟦 Listed: id=${args.listingId} seller=${args.seller} nft=${args.nft} tokenId=${args.tokenId} payToken=${args.payToken} price=${args.price}`
        );
      }
    },
  });

  // Bought(listingId, buyer, seller, nft, tokenId, payToken, price)
  client.watchEvent({
    address: MARKET,
    event: parseAbiItem(
      "event Bought(uint256 indexed listingId, address indexed buyer, address indexed seller, address nft, uint256 tokenId, address payToken, uint256 price)"
    ),
    onLogs: (logs) => {
      for (const l of logs) {
        const args = l.args as any;
        console.log(
          `[${now()}] 🟩 Bought: id=${args.listingId} buyer=${args.buyer} seller=${args.seller} nft=${args.nft} tokenId=${args.tokenId} payToken=${args.payToken} price=${args.price}`
        );
      }
    },
  });

  console.log(`[${now()}] 👂 watching events...`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
