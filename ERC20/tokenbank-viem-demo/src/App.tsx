import { useEffect, useMemo, useState } from "react";
import {
  createPublicClient,
  createWalletClient,
  custom,
  formatUnits,
  http,
  parseUnits,
  type Address,
} from "viem";
import { sepolia } from "viem/chains";

// ====== 1) 改成你自己的合约地址 ======
const tokenAddress = "0xE503984Aad3C921Ef3358424a61A71D276868F3b" as Address;
const bankV2Address = "0x65829af43acb15997e7b1592df3fa53c88d4fb4e" as Address;

// ====== 2) 最小 ABI（只保留用到的函数/事件） ======
const tokenAbi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "_owner", type: "address" }],
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
    name: "transferWithCallback",
    stateMutability: "nonpayable",
    inputs: [
      { name: "_to", type: "address" },
      { name: "_value", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
  },
] as const;

const bankAbi = [
  {
    type: "function",
    name: "depositedOf",
    stateMutability: "view",
    inputs: [{ name: "user", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
  {
    type: "function",
    name: "withdraw",
    stateMutability: "nonpayable",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "event",
    name: "Deposit",
    inputs: [
      { name: "user", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Withdraw",
    inputs: [
      { name: "user", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
    anonymous: false,
  },
] as const;

export default function App() {
  const [account, setAccount] = useState<Address | null>(null);
  const [status, setStatus] = useState<string>("");
  const [decimals, setDecimals] = useState<number>(18);

  const [tokenBalance, setTokenBalance] = useState<bigint>(0n);
  const [deposited, setDeposited] = useState<bigint>(0n);

  const [depositInput, setDepositInput] = useState<string>("1");

  const publicClient = useMemo(() => {
    // 你也可以换成自己的 RPC：http("https://...")；这里用 sepolia 默认示例
    return createPublicClient({
      chain: sepolia,
      transport: http(),
    });
  }, []);

  const walletClient = useMemo(() => {
    if (!(window as any).ethereum) return null;
    return createWalletClient({
      chain: sepolia,
      transport: custom((window as any).ethereum),
    });
  }, []);

  async function connect() {
    try {
      setStatus("");
      if (!walletClient) throw new Error("未检测到钱包（MetaMask）");
      const [addr] = await walletClient.requestAddresses();
      setAccount(addr);
    } catch (e: any) {
      setStatus(e?.message ?? String(e));
    }
  }

  async function refresh() {
    try {
      setStatus("");
      // decimals 可缓存（只要 token 不变）
      const d = await publicClient.readContract({
        address: tokenAddress,
        abi: tokenAbi,
        functionName: "decimals",
      });
      setDecimals(Number(d));

      if (!account) return;

      const [bal, dep] = await Promise.all([
        publicClient.readContract({
          address: tokenAddress,
          abi: tokenAbi,
          functionName: "balanceOf",
          args: [account],
        }),
        publicClient.readContract({
          address: bankV2Address,
          abi: bankAbi,
          functionName: "depositedOf",
          args: [account],
        }),
      ]);

      setTokenBalance(bal);
      setDeposited(dep);
    } catch (e: any) {
      setStatus(e?.message ?? String(e));
    }
  }

  // 存款：直接 token.transferWithCallback(bankV2, amount)
  async function depositWithCallback() {
    try {
      setStatus("");
      if (!walletClient) throw new Error("未检测到钱包（MetaMask）");
      if (!account) throw new Error("请先连接钱包");

      const amount = parseUnits(depositInput || "0", decimals);
      if (amount <= 0n) throw new Error("存款数量必须 > 0");

      const hash = await walletClient.writeContract({
        address: tokenAddress,
        abi: tokenAbi,
        functionName: "transferWithCallback",
        args: [bankV2Address, amount],
        account,
      });

      setStatus(`已发送存款交易：${hash}（等待确认...）`);
      await publicClient.waitForTransactionReceipt({ hash });
      setStatus(`存款已确认：${hash}`);
      await refresh();
    } catch (e: any) {
      setStatus(e?.shortMessage ?? e?.message ?? String(e));
    }
  }

  async function withdrawAll() {
    try {
      setStatus("");
      if (!walletClient) throw new Error("未检测到钱包（MetaMask）");
      if (!account) throw new Error("请先连接钱包");

      const hash = await walletClient.writeContract({
        address: bankV2Address,
        abi: bankAbi,
        functionName: "withdraw",
        account,
      });

      setStatus(`已发送取款交易：${hash}（等待确认...）`);
      await publicClient.waitForTransactionReceipt({ hash });
      setStatus(`取款已确认：${hash}`);
      await refresh();
    } catch (e: any) {
      setStatus(e?.shortMessage ?? e?.message ?? String(e));
    }
  }

  // 初次连接后刷新 & 监听事件（Deposit/Withdraw -> 自动刷新）
  useEffect(() => {
    refresh();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [account]);

  useEffect(() => {
    if (!account) return;

    const unwatchDeposit = publicClient.watchContractEvent({
      address: bankV2Address,
      abi: bankAbi,
      eventName: "Deposit",
      onLogs: async (logs) => {
        // 只要有存款事件就刷新（最简单）
        console.log("Deposit logs:", logs);
        await refresh();
      },
    });

    const unwatchWithdraw = publicClient.watchContractEvent({
      address: bankV2Address,
      abi: bankAbi,
      eventName: "Withdraw",
      onLogs: async (logs) => {
        console.log("Withdraw logs:", logs);
        await refresh();
      },
    });

    return () => {
      unwatchDeposit?.();
      unwatchWithdraw?.();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [account, publicClient]);

  const tokenBalanceFmt = formatUnits(tokenBalance, decimals);
  const depositedFmt = formatUnits(deposited, decimals);

  return (
    <div style={{ maxWidth: 720, margin: "40px auto", fontFamily: "system-ui" }}>
      <h2>TokenBankV2 (viem) Minimal Demo</h2>

      <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
        <button onClick={connect} disabled={!walletClient}>
          {account ? "已连接" : "连接钱包"}
        </button>
        <button onClick={refresh} disabled={!account}>
          刷新数据
        </button>
        <div style={{ fontSize: 12, opacity: 0.8 }}>
          网络：Sepolia
        </div>
      </div>

      <hr style={{ margin: "16px 0" }} />

      <div style={{ fontSize: 14, lineHeight: 1.8 }}>
        <div>
          <b>Account:</b> {account ?? "-"}
        </div>
        <div>
          <b>Token:</b> {tokenAddress}
        </div>
        <div>
          <b>TokenBankV2:</b> {bankV2Address}
        </div>
        <div>
          <b>Token Balance:</b> {account ? tokenBalanceFmt : "-"}
        </div>
        <div>
          <b>Deposited In Bank:</b> {account ? depositedFmt : "-"}
        </div>
      </div>

      <hr style={{ margin: "16px 0" }} />

      <h3>存款（transferWithCallback）</h3>
      <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
        <input
          value={depositInput}
          onChange={(e) => setDepositInput(e.target.value)}
          placeholder="存款数量（例如 1）"
          style={{ padding: 8, width: 220 }}
        />
        <button onClick={depositWithCallback} disabled={!account}>
          存款
        </button>
      </div>
      <div style={{ fontSize: 12, opacity: 0.8, marginTop: 8 }}>
        这里不会调用 approve/deposit，而是：token.transferWithCallback(bankV2, amount)
      </div>

      <h3 style={{ marginTop: 22 }}>取款（withdraw 全部）</h3>
      <button onClick={withdrawAll} disabled={!account}>
        取出全部
      </button>

      <hr style={{ margin: "16px 0" }} />

      <div style={{ whiteSpace: "pre-wrap", fontSize: 12 }}>
        <b>Status:</b> {status || "-"}
      </div>
    </div>
  );
}
