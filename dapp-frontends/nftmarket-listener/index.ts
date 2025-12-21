import {
  createPublicClient,
  webSocket,
  type Address,
  type Hex,
  formatUnits,
} from "viem";
import { sepolia } from "viem/chains";

/**
 * ========= 你需要修改的配置 =========
 */
// 1) 你的 NFTMarket 合约地址
const MARKET_ADDRESS = "0x67ac7d5b683bAfAF357d79084F89C44bC8743228" as Address;

// 2) WebSocket RPC（强烈建议用 WS，否则监听会变成轮询）
const WS_RPC_URL = "wss://0xrpc.io/sep";

// 3) 可选：启动时先补历史事件（避免你服务晚启动漏掉事件）
//    - 设为 0n：从创世开始（太慢不推荐）
//    - 设为某个部署区块：最佳实践
//    - 设为 undefined：不拉历史，只监听实时
const FROM_BLOCK: bigint | undefined = undefined; // 例如：1234567n

/**
 * ========= ABI：只保留事件 =========
 * 注意：要和合约定义严格一致（indexed 与否必须对齐）
 */
const marketAbi = [
  {
    type: "event",
    name: "Listed",
    inputs: [
      { name: "listingId", type: "uint256", indexed: true },
      { name: "seller", type: "address", indexed: true },
      { name: "nft", type: "address", indexed: true },
      { name: "tokenId", type: "uint256", indexed: false },
      { name: "payToken", type: "address", indexed: false },
      { name: "price", type: "uint256", indexed: false },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Bought",
    inputs: [
      { name: "listingId", type: "uint256", indexed: true },
      { name: "buyer", type: "address", indexed: true },
      { name: "seller", type: "address", indexed: true },
      // 你的合约里 Bought 事件的 nft 没有 indexed（对齐你贴的代码）
      { name: "nft", type: "address", indexed: false },
      { name: "tokenId", type: "uint256", indexed: false },
      { name: "payToken", type: "address", indexed: false },
      { name: "price", type: "uint256", indexed: false },
    ],
    anonymous: false,
  },
] as const;

/**
 * ========= client：只读（监听不需要钱包/签名） =========
 */
const client = createPublicClient({
  chain: sepolia,
  transport: webSocket(WS_RPC_URL),
});

/**
 * ========= 工具函数 =========
 */
function now() {
  return new Date().toISOString();
}

function fmtAddr(a: Address) {
  return `${a.slice(0, 6)}...${a.slice(-4)}`;
}

function safeToString(x: unknown) {
  try {
    // bigint / number / string 都能 toString
    // @ts-ignore
    return x?.toString?.() ?? String(x);
  } catch {
    return String(x);
  }
}

function logHeader(tag: string) {
  console.log(`\n[${now()}] ${tag}`);
}

/**
 * ========= 处理 Listed =========
 */
function handleListed(log: {
  args: any;
  transactionHash: Hex;
  blockNumber: bigint | null;
}) {
  const args = log.args;

  // ✅ 严格判空，解决 TS18048，同时也防止运行时崩溃
  if (
    args?.listingId === undefined ||
    args?.seller === undefined ||
    args?.nft === undefined ||
    args?.tokenId === undefined ||
    args?.payToken === undefined ||
    args?.price === undefined
  ) {
    logHeader("⚠️ Listed (args not fully decoded)");
    console.log({ txHash: log.transactionHash, blockNumber: log.blockNumber });
    console.log(args);
    return;
  }

  logHeader("📌 NFT Listed");
  console.log({
    listingId: safeToString(args.listingId),
    seller: args.seller,
    sellerShort: fmtAddr(args.seller),
    nft: args.nft,
    tokenId: safeToString(args.tokenId),
    payToken: args.payToken,
    priceRaw: safeToString(args.price),
    // 如果你确定 payToken decimals=18，可以顺手格式化一下（可选）
    // priceFmt18: formatUnits(args.price, 18),
    txHash: log.transactionHash,
    blockNumber: log.blockNumber ? safeToString(log.blockNumber) : null,
  });
}

/**
 * ========= 处理 Bought =========
 */
function handleBought(log: {
  args: any;
  transactionHash: Hex;
  blockNumber: bigint | null;
}) {
  const args = log.args;

  if (
    args?.listingId === undefined ||
    args?.buyer === undefined ||
    args?.seller === undefined ||
    args?.nft === undefined ||
    args?.tokenId === undefined ||
    args?.payToken === undefined ||
    args?.price === undefined
  ) {
    logHeader("⚠️ Bought (args not fully decoded)");
    console.log({ txHash: log.transactionHash, blockNumber: log.blockNumber });
    console.log(args);
    return;
  }

  logHeader("💰 NFT Bought");
  console.log({
    listingId: safeToString(args.listingId),
    buyer: args.buyer,
    buyerShort: fmtAddr(args.buyer),
    seller: args.seller,
    sellerShort: fmtAddr(args.seller),
    nft: args.nft,
    tokenId: safeToString(args.tokenId),
    payToken: args.payToken,
    priceRaw: safeToString(args.price),
    // priceFmt18: formatUnits(args.price, 18), // 可选
    txHash: log.transactionHash,
    blockNumber: log.blockNumber ? safeToString(log.blockNumber) : null,
  });
}

/**
 * ========= 启动时补历史 =========
 */
async function backfillHistory() {
  if (FROM_BLOCK === undefined) {
    console.log(`[${now()}] ℹ️ Skip history backfill (FROM_BLOCK is undefined)`);
    return;
  }

  try {
    const latest = await client.getBlockNumber();
    console.log(
      `[${now()}] 📚 Backfill history logs from block ${FROM_BLOCK} to ${latest}`
    );

    // 1) 拉 Listed 历史
    const listedLogs = await client.getLogs({
      address: MARKET_ADDRESS,
      event: marketAbi[0], // Listed
      fromBlock: FROM_BLOCK,
      toBlock: latest,
    });

    for (const l of listedLogs) {
      handleListed({
        args: (l as any).args,
        transactionHash: l.transactionHash,
        blockNumber: l.blockNumber ?? null,
      });
    }

    // 2) 拉 Bought 历史
    const boughtLogs = await client.getLogs({
      address: MARKET_ADDRESS,
      event: marketAbi[1], // Bought
      fromBlock: FROM_BLOCK,
      toBlock: latest,
    });

    for (const l of boughtLogs) {
      handleBought({
        args: (l as any).args,
        transactionHash: l.transactionHash,
        blockNumber: l.blockNumber ?? null,
      });
    }

    console.log(`[${now()}] ✅ Backfill done. Listed=${listedLogs.length}, Bought=${boughtLogs.length}`);
  } catch (e: any) {
    console.log(`[${now()}] ❌ Backfill failed:`, e?.message ?? e);
  }
}

/**
 * ========= 实时监听 =========
 */
function watchRealtime() {
  console.log(`[${now()}] 👂 Start watching events...`);
  console.log(`Market: ${MARKET_ADDRESS}`);
  console.log(`WS RPC: ${WS_RPC_URL}`);

  const unwatchListed = client.watchContractEvent({
    address: MARKET_ADDRESS,
    abi: marketAbi,
    eventName: "Listed",
    onLogs(logs) {
      try {
        for (const l of logs as any[]) {
          handleListed({
            args: l.args,
            transactionHash: l.transactionHash,
            blockNumber: l.blockNumber ?? null,
          });
        }
      } catch (e: any) {
        console.log(`[${now()}] ❌ Listed handler error:`, e?.message ?? e);
      }
    },
    onError(err) {
      console.log(`[${now()}] ❌ watch Listed error:`, err?.message ?? err);
    },
  });

  const unwatchBought = client.watchContractEvent({
    address: MARKET_ADDRESS,
    abi: marketAbi,
    eventName: "Bought",
    onLogs(logs) {
      try {
        for (const l of logs as any[]) {
          handleBought({
            args: l.args,
            transactionHash: l.transactionHash,
            blockNumber: l.blockNumber ?? null,
          });
        }
      } catch (e: any) {
        console.log(`[${now()}] ❌ Bought handler error:`, e?.message ?? e);
      }
    },
    onError(err) {
      console.log(`[${now()}] ❌ watch Bought error:`, err?.message ?? err);
    },
  });

  // 进程退出时取消订阅
  const cleanup = () => {
    console.log(`\n[${now()}] 🧹 Shutting down...`);
    try {
      unwatchListed?.();
      unwatchBought?.();
    } catch {}
    process.exit(0);
  };

  process.on("SIGINT", cleanup);
  process.on("SIGTERM", cleanup);
}

/**
 * ========= main =========
 */
async function main() {
  console.log(`[${now()}] ✅ NFTMarket listener booting...`);

  // 简单检查：能否连上节点、能否读到区块号
  try {
    const bn = await client.getBlockNumber();
    console.log(`[${now()}] 🔗 Connected. Current block = ${bn}`);
  } catch (e: any) {
    console.log(`[${now()}] ❌ Cannot connect to RPC:`, e?.message ?? e);
    process.exit(1);
  }

  await backfillHistory();
  watchRealtime();
}

main().catch((e) => {
  console.error(`[${now()}] ❌ Fatal:`, e);
  process.exit(1);
});
