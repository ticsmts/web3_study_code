import "dotenv/config";
import { randomBytes } from "crypto";
import fs from "fs";
import {
  createPublicClient,
  createWalletClient,
  http,
  formatEther,
  formatUnits,
  parseUnits,
  encodeFunctionData,
  isAddress,
} from "viem";
import { sepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

const RPC_URL =
  process.env.SEPOLIA_RPC_URL || "https://ethereum-sepolia-rpc.publicnode.com";

const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(RPC_URL),
});

function requirePrivateKey() {
  const pk = process.env.PRIVATE_KEY;
  if (!pk || !pk.startsWith("0x") || pk.length !== 66) {
    throw new Error(
      "PRIVATE_KEY 缺失或格式不对。请在 .env 设置 PRIVATE_KEY=0x<64 hex>（不要带引号）"
    );
  }
  return pk;
}

function getAccountAndWalletClient() {
  const pk = requirePrivateKey();
  const account = privateKeyToAccount(pk);
  const walletClient = createWalletClient({
    account,
    chain: sepolia,
    transport: http(RPC_URL),
  });
  return { account, walletClient };
}

// 你的 ZZTOKEN 默认地址（也可以命令行传入覆盖）
const DEFAULT_TOKEN = "0x5C4829789Cb5d86b15034D7E8C8ddDcb45890Cff";

// 极简 ERC20 ABI：balance/decimals/symbol/transfer
const erc20Abi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "owner", type: "address" }],
    outputs: [{ name: "balance", type: "uint256" }],
  },
  {
    type: "function",
    name: "decimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "symbol",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
  },
  {
    type: "function",
    name: "transfer",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "value", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
];

async function getTokenMeta(token) {
  // 兼容一些非标准 token：读不到就给默认值
  let symbol = "TOKEN";
  let decimals = 18;

  try {
    symbol = await publicClient.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "symbol",
    });
  } catch {}

  try {
    decimals = await publicClient.readContract({
      address: token,
      abi: erc20Abi,
      functionName: "decimals",
    });
  } catch {}

  return { symbol, decimals };
}

async function cmdNew() {
  const pk = `0x${randomBytes(32).toString("hex")}`;
  const account = privateKeyToAccount(pk);

  console.log("=== 生成新账号 ===");
  console.log("address:", account.address);
  console.log("privateKey:", pk);
  console.log("");
  console.log("把 privateKey 写进 .env 的 PRIVATE_KEY=... 然后运行：");
  console.log("  node wallet.mjs balance");
}

async function cmdAddress() {
  const { account } = getAccountAndWalletClient();
  console.log("address:", account.address);
}

async function cmdBalance() {
  const { account } = getAccountAndWalletClient();
  const token = process.argv[3] || DEFAULT_TOKEN;
  if (!isAddress(token)) throw new Error("token 合约地址不合法");

  const ethBal = await publicClient.getBalance({ address: account.address });
  const { symbol, decimals } = await getTokenMeta(token);
  const tokenBal = await publicClient.readContract({
    address: token,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [account.address],
  });

  console.log("RPC:", RPC_URL);
  console.log("address:", account.address);
  console.log("ETH:", formatEther(ethBal));
  console.log(`${symbol}(${token}):`, formatUnits(tokenBal, decimals));
}

// 构造 EIP-1559 的 ERC20 transfer 交易，并保存到 tx.json
async function  cmdBuildTransfer() {
  const token = process.argv[3] || DEFAULT_TOKEN;
  const to = process.argv[4];
  const amountHuman = process.argv[5];

  if (!isAddress(token)) throw new Error("token 合约地址不合法");
  if (!isAddress(to)) throw new Error("收款地址不合法");
  if (!amountHuman) throw new Error("缺少 amount（例如 12.34）");

  const { account } = getAccountAndWalletClient();
  const { symbol, decimals } = await getTokenMeta(token);

  // 1) 把人类输入的 amount 转成 token 最小单位（uint256）
  const amount = parseUnits(amountHuman, decimals);

  // 2) data = encode(transfer(to, amount))
  const data = encodeFunctionData({
    abi: erc20Abi,
    functionName: "transfer",
    args: [to, amount],
  });

  // 3) nonce：当前账户发出的第几笔交易
  const nonce = await publicClient.getTransactionCount({
    address: account.address,
    blockTag: "pending",
  });

  // 4) EIP-1559 fee 建议值（Viem 会根据当前网络估计）
  const fees = await publicClient.estimateFeesPerGas();

  // 5) gas 估算：这笔合约调用大概要多少 gas
  //    注意：estimateGas 需要 from/to/data
  const gas = await publicClient.estimateGas({
    account: account.address,
    to: token,
    data,
    value: 0n,
  });

  const txRequest = {
    chainId: sepolia.id,           // 11155111
    type: "eip1559",
    from: account.address,         // 仅用于展示/理解，签名时会用 account
    to: token,                     // 目标是 token 合约
    data,                          // transfer calldata
    value: 0n,
    nonce,
    gas,
    maxFeePerGas: fees.maxFeePerGas,
    maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
  };

  //fs.writeFileSync("tx.json", JSON.stringify(txRequest, null, 2));
  const json = JSON.stringify(
    txRequest,
    (_, v) => (typeof v === "bigint" ? v.toString() : v),
    2
  );
  fs.writeFileSync("tx.json", json);


  console.log("=== 已构造交易并保存到 tx.json ===");
  console.log(`Token: ${symbol}  decimals=${decimals}`);
  console.log(`Transfer: ${amountHuman} ${symbol} -> ${to}`);
  console.log("下一步：node wallet.mjs sign tx.json");
}

// 签名 tx.json，输出 rawtx.txt
async function cmdSign(file) {
  if (!file) throw new Error("用法：node wallet.mjs sign tx.json");
  const raw = fs.readFileSync(file, "utf-8");
  const tx = JSON.parse(raw);

  const { walletClient } = getAccountAndWalletClient();

  // signTransaction 需要：to/data/value/nonce/gas/fees/chainId/type
  const serialized = await walletClient.signTransaction({
    to: tx.to,
    data: tx.data,
    value: BigInt(tx.value),
    nonce: Number(tx.nonce),
    gas: BigInt(tx.gas),
    chainId: Number(tx.chainId),
    type: "eip1559",
    maxFeePerGas: BigInt(tx.maxFeePerGas),
    maxPriorityFeePerGas: BigInt(tx.maxPriorityFeePerGas),
  });

  fs.writeFileSync("rawtx.txt", serialized);
  console.log("=== 已签名，原始交易保存到 rawtx.txt ===");
  console.log("下一步：node wallet.mjs send rawtx.txt");
}

// 广播 rawtx.txt 上链，等待回执
async function cmdSend(file) {
  if (!file) throw new Error("用法：node wallet.mjs send rawtx.txt");
  const serialized = fs.readFileSync(file, "utf-8").trim();

  const hash = await publicClient.sendRawTransaction({
    serializedTransaction: serialized,
  });

  console.log("txHash:", hash);
  console.log("等待打包...");

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log("=== 已上链 ===");
  console.log("status:", receipt.status); // "success" or "reverted"
  console.log("blockNumber:", receipt.blockNumber?.toString());
  console.log("gasUsed:", receipt.gasUsed?.toString());
}

// 一键：build + sign + send
async function cmdTransfer() {
  // 复用 build 的参数格式：transfer <token> <to> <amount>
  const token = process.argv[3] || DEFAULT_TOKEN;
  const to = process.argv[4];
  const amountHuman = process.argv[5];
  if (!to || !amountHuman) {
    throw new Error("用法：node wallet.mjs transfer <token?> <to> <amount>");
  }

  // 先 build 到内存（不强依赖文件），再 sign，再 send
  if (!isAddress(token)) throw new Error("token 合约地址不合法");
  if (!isAddress(to)) throw new Error("收款地址不合法");

  const { account, walletClient } = getAccountAndWalletClient();
  const { symbol, decimals } = await getTokenMeta(token);
  const amount = parseUnits(amountHuman, decimals);

  const data = encodeFunctionData({
    abi: erc20Abi,
    functionName: "transfer",
    args: [to, amount],
  });

  const nonce = await publicClient.getTransactionCount({
    address: account.address,
    blockTag: "pending",
  });

  const fees = await publicClient.estimateFeesPerGas();
  const gas = await publicClient.estimateGas({
    account: account.address,
    to: token,
    data,
    value: 0n,
  });

  const serialized = await walletClient.signTransaction({
    to: token,
    data,
    value: 0n,
    nonce,
    gas,
    chainId: sepolia.id,
    type: "eip1559",
    maxFeePerGas: fees.maxFeePerGas,
    maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
  });

  const hash = await publicClient.sendRawTransaction({
    serializedTransaction: serialized,
  });

  console.log(`已发送：${amountHuman} ${symbol} -> ${to}`);
  console.log("txHash:", hash);

  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log("status:", receipt.status);
  console.log("blockNumber:", receipt.blockNumber?.toString());
}

async function main() {
  const cmd = process.argv[2];

  try {
    if (cmd === "new") return await cmdNew();
    if (cmd === "address") return await cmdAddress();
    if (cmd === "balance") return await cmdBalance();

    if (cmd === "build-transfer") return await cmdBuildTransfer();
    if (cmd === "sign") return await cmdSign(process.argv[3]);
    if (cmd === "send") return await cmdSend(process.argv[3]);
    if (cmd === "transfer") return await cmdTransfer();

    console.log("用法：");
    console.log("  node wallet.mjs new");
    console.log("  node wallet.mjs address");
    console.log("  node wallet.mjs balance <token?>      # 默认 ZZTOKEN");
    console.log("");
    console.log("  node wallet.mjs build-transfer <token?> <to> <amount>");
    console.log("  node wallet.mjs sign tx.json");
    console.log("  node wallet.mjs send rawtx.txt");
    console.log("  node wallet.mjs transfer <token?> <to> <amount>   # 一键");
    process.exit(1);
  } catch (e) {
    console.error("错误：", e?.message || e);
    process.exit(1);
  }
}

main();
