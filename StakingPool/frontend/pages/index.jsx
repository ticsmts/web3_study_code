import { useCallback, useEffect, useMemo, useState } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { formatEther, parseEther, parseEventLogs } from "viem";
import {
  useAccount,
  useBalance,
  useBlockNumber,
  useReadContract,
  useWriteContract,
  usePublicClient
} from "wagmi";

import {
  aTokenAbi,
  getEnvAddresses,
  mockLendingPoolAbi,
  stakingPoolAbi,
  tokenAbi
} from "../lib/contracts";

export default function Home() {
  const { address, isConnected, chain } = useAccount();
  const { stakingPool, zzToken, aToken, lendingPool, weth } = getEnvAddresses();
  const [amount, setAmount] = useState("1.0");
  const [status, setStatus] = useState("");
  const [pendingAction, setPendingAction] = useState("");
  const [toasts, setToasts] = useState([]);
  const [activity, setActivity] = useState([]);
  const [activityStatus, setActivityStatus] = useState("idle");
  const chainId = chain?.id;
  const publicClient = usePublicClient({ chainId });
  const blockNumber = useBlockNumber({ chainId, watch: true });

  const ethBalance = useBalance({ address, chainId, query: { enabled: !!address && !!chainId } });

  const userStake = useReadContract({
    address: stakingPool,
    abi: stakingPoolAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!address && !!stakingPool && !!chainId, refetchInterval: 6000 }
  });

  const earned = useReadContract({
    address: stakingPool,
    abi: stakingPoolAbi,
    functionName: "earned",
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!address && !!stakingPool && !!chainId, refetchInterval: 6000 }
  });

  const zzBalance = useReadContract({
    address: zzToken,
    abi: tokenAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    chainId,
    query: { enabled: !!address && !!zzToken && !!chainId, refetchInterval: 8000 }
  });

  const totalStaked = useReadContract({
    address: stakingPool,
    abi: stakingPoolAbi,
    functionName: "totalStaked",
    chainId,
    query: { enabled: !!stakingPool && !!chainId, refetchInterval: 8000 }
  });

  const poolATokenBalance = useReadContract({
    address: aToken,
    abi: aTokenAbi,
    functionName: "balanceOf",
    args: stakingPool ? [stakingPool] : undefined,
    chainId,
    query: { enabled: !!aToken && !!stakingPool && !!chainId, refetchInterval: 10000 }
  });

  const poolATokenSymbol = useReadContract({
    address: aToken,
    abi: aTokenAbi,
    functionName: "symbol",
    chainId,
    query: { enabled: !!aToken && !!chainId }
  });

  const { writeContractAsync } = useWriteContract();

  const formattedStake = useMemo(() => {
    if (!userStake.data) return "0";
    return formatEther(userStake.data);
  }, [userStake.data]);

  const formattedEarned = useMemo(() => {
    if (!earned.data) return "0";
    return formatEther(earned.data);
  }, [earned.data]);

  const formattedZZ = useMemo(() => {
    if (!zzBalance.data) return "0";
    return formatEther(zzBalance.data);
  }, [zzBalance.data]);

  const formattedTotalStaked = useMemo(() => {
    if (!totalStaked.data) return "0";
    return formatEther(totalStaked.data);
  }, [totalStaked.data]);

  const formattedPoolAToken = useMemo(() => {
    if (!poolATokenBalance.data) return "0";
    return formatEther(poolATokenBalance.data);
  }, [poolATokenBalance.data]);

  const formattedInterest = useMemo(() => {
    if (!poolATokenBalance.data || !totalStaked.data) return "0";
    const diff = poolATokenBalance.data > totalStaked.data ? poolATokenBalance.data - totalStaked.data : 0n;
    return formatEther(diff);
  }, [poolATokenBalance.data, totalStaked.data]);

  const hasConfig = Boolean(stakingPool);
  const hasLendingConfig = Boolean(aToken && stakingPool);
  const hasMockAccrue = Boolean(lendingPool && weth && stakingPool);

  const loadActivity = useCallback(async () => {
    if (!publicClient || !stakingPool || !chainId) {
      setActivityStatus("idle");
      return;
    }
    setActivityStatus("loading");
    try {
      const blockNumber = await publicClient.getBlockNumber();
      const fromBlock = blockNumber > 2000n ? blockNumber - 2000n : 0n;
      const logs = await publicClient.getLogs({
        address: stakingPool,
        fromBlock,
        toBlock: blockNumber
      });
      const parsed = parseEventLogs({ abi: stakingPoolAbi, logs });
      const filtered = parsed
        .filter((item) => ["Stake", "Unstake", "Claim"].includes(item.eventName))
        .map((item) => ({
          eventName: item.eventName,
          args: item.args,
          log: item.log
        }))
        .sort((a, b) => (a.log.blockNumber > b.log.blockNumber ? -1 : 1))
        .slice(0, 5);

      const enriched = await Promise.all(
        filtered.map(async (item) => {
          let time = "-";
          try {
            const block = await publicClient.getBlock({ blockNumber: item.log.blockNumber });
            time = new Date(Number(block.timestamp) * 1000).toLocaleTimeString();
          } catch (error) {
            time = "-";
          }

          const amountValue = item.args?.amount ?? 0n;
          const unit = item.eventName === "Claim" ? "ZZ" : "ETH";
          return {
            id: `${item.log.transactionHash}-${item.log.logIndex}`,
            type: item.eventName,
            amount: `${formatEther(amountValue)} ${unit}`,
            user: item.args?.user,
            time,
            hash: item.log.transactionHash,
            blockNumber: item.log.blockNumber
          };
        })
      );

      setActivity(enriched);
      setActivityStatus("ready");
    } catch (error) {
      setActivityStatus("error");
    }
  }, [publicClient, stakingPool, chainId]);

  useEffect(() => {
    loadActivity();
  }, [loadActivity, chainId]);

  useEffect(() => {
    if (!blockNumber.data || !chainId) return;
    earned.refetch?.();
    userStake.refetch?.();
    zzBalance.refetch?.();
    totalStaked.refetch?.();
    poolATokenBalance.refetch?.();
  }, [blockNumber.data, chainId, earned, userStake, zzBalance, totalStaked, poolATokenBalance]);

  function pushToast(type, message) {
    const id = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
    setToasts((current) => [...current, { id, type, message }]);
    setTimeout(() => {
      setToasts((current) => current.filter((toast) => toast.id !== id));
    }, 4200);
  }

  function classifyError(error) {
    const message = error?.shortMessage || error?.message || "交易失败";
    if (/User rejected|User denied|拒绝|rejected/i.test(message)) {
      return { level: "warn", message: "用户已取消交易" };
    }
    if (/insufficient funds|余额不足|funds/i.test(message)) {
      return { level: "error", message: "余额不足或 gas 不够" };
    }
    if (/config|address|undefined/i.test(message)) {
      return { level: "error", message: "配置缺失或合约地址无效" };
    }
    return { level: "error", message };
  }

  function parseAmount() {
    if (!amount || Number(amount) <= 0) {
      return null;
    }
    return parseEther(amount);
  }

  async function waitForConfirm(hash) {
    if (!hash || !publicClient) return;
    await publicClient.waitForTransactionReceipt({ hash });
  }

  function shortHash(hash) {
    return `${hash.slice(0, 6)}...${hash.slice(-4)}`;
  }

  async function handleStake() {
    try {
      const value = parseAmount();
      if (!value) {
        pushToast("warn", "请输入正确的质押数量");
        return;
      }
      setPendingAction("stake");
      setStatus("提交 stake 交易中...");
      const hash = await writeContractAsync({
        address: stakingPool,
        abi: stakingPoolAbi,
        functionName: "stake",
        value
      });
      setStatus(`stake 已发送 ${shortHash(hash)}`);
      pushToast("info", "交易已发送，等待确认");
      await waitForConfirm(hash);
      setStatus("stake 已确认");
      pushToast("success", "质押已确认");
      loadActivity();
    } catch (error) {
      const detail = classifyError(error);
      setStatus(detail.message);
      pushToast(detail.level, detail.message);
    } finally {
      setPendingAction("");
    }
  }

  async function handleClaim() {
    try {
      setPendingAction("claim");
      setStatus("提交 claim 交易中...");
      const hash = await writeContractAsync({
        address: stakingPool,
        abi: stakingPoolAbi,
        functionName: "claim"
      });
      setStatus(`claim 已发送 ${shortHash(hash)}`);
      pushToast("info", "交易已发送，等待确认");
      await waitForConfirm(hash);
      setStatus("claim 已确认");
      pushToast("success", "奖励已领取");
      loadActivity();
    } catch (error) {
      const detail = classifyError(error);
      setStatus(detail.message);
      pushToast(detail.level, detail.message);
    } finally {
      setPendingAction("");
    }
  }

  async function handleUnstake() {
    try {
      const value = parseAmount();
      if (!value) {
        pushToast("warn", "请输入正确的赎回数量");
        return;
      }
      setPendingAction("unstake");
      setStatus("提交 unstake 交易中...");
      const hash = await writeContractAsync({
        address: stakingPool,
        abi: stakingPoolAbi,
        functionName: "unstake",
        args: [value]
      });
      setStatus(`unstake 已发送 ${shortHash(hash)}`);
      pushToast("info", "交易已发送，等待确认");
      await waitForConfirm(hash);
      setStatus("unstake 已确认");
      pushToast("success", "赎回已确认");
      loadActivity();
    } catch (error) {
      const detail = classifyError(error);
      setStatus(detail.message);
      pushToast(detail.level, detail.message);
    } finally {
      setPendingAction("");
    }
  }

  async function handleAccrue() {
    if (!hasMockAccrue) {
      pushToast("warn", "请先配置 MockLendingPool 和 WETH 地址");
      return;
    }
    try {
      setPendingAction("accrue");
      setStatus("模拟利息累积中...");
      const value = parseEther("0.5");
      const hash = await writeContractAsync({
        address: lendingPool,
        abi: mockLendingPoolAbi,
        functionName: "accrue",
        args: [weth, stakingPool, value]
      });
      setStatus(`accrue 已发送 ${shortHash(hash)}`);
      pushToast("info", "利息模拟交易已发送");
      await waitForConfirm(hash);
      setStatus("利息已模拟");
      pushToast("success", "利息已累积");
      loadActivity();
    } catch (error) {
      const detail = classifyError(error);
      setStatus(detail.message);
      pushToast(detail.level, detail.message);
    } finally {
      setPendingAction("");
    }
  }

  return (
    <>
      <div className="fixed right-6 top-6 z-50 flex w-[260px] flex-col gap-2">
        {toasts.map((toast) => (
          <div
            key={toast.id}
            className={`rounded-2xl border px-4 py-3 text-xs shadow-lg backdrop-blur ${
              toast.type === "success"
                ? "border-emerald-200 bg-emerald-50/80 text-emerald-800"
                : toast.type === "info"
                  ? "border-sky-200 bg-sky-50/80 text-sky-800"
                  : toast.type === "warn"
                    ? "border-amber-200 bg-amber-50/80 text-amber-800"
                    : "border-rose-200 bg-rose-50/80 text-rose-800"
            }`}
          >
            {toast.message}
          </div>
        ))}
      </div>
      <div className="orb one"></div>
      <div className="orb two"></div>
      <div className="orb three"></div>

      <main className="relative z-10 mx-auto min-h-screen max-w-5xl px-7 pb-24 pt-16">
        <header className="reveal flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
          <div className="flex items-center gap-3">
            <div className="grid h-10 w-10 place-items-center rounded-xl border border-white/40 bg-white/60 font-semibold shadow-lg">
              ZZ
            </div>
            <div>
              <div className="font-serif text-2xl tracking-[0.2em]">StakingPool</div>
              <div className="text-xs uppercase tracking-[0.3em] text-black/40">glass + neo</div>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <div className="rounded-full border border-black/10 bg-white/70 px-4 py-2 text-[10px] uppercase tracking-[0.35em]">
              10 ZZ / block
            </div>
            <div className="rounded-full border border-black/10 bg-white/70 px-4 py-2 text-[10px] uppercase tracking-[0.35em]">
              auto lending
            </div>
            <ConnectButton showBalance={false} chainStatus="icon" />
          </div>
        </header>

        <section className="mt-14 grid gap-8 md:grid-cols-[minmax(280px,1fr)_minmax(280px,1fr)]">
          <div className="reveal delay-1">
            <h1 className="font-serif text-4xl leading-tight md:text-5xl">
              像呼吸一样流动的质押收益
            </h1>
            <p className="mt-5 max-w-xl text-base leading-7 text-black/70">
              玻璃拟态的透明层次结合触感丰富的新拟态控件，为链上资产提供柔和而有分量的
              操作体验。质押 ETH，获得 ZZ 激励，并自动接入借贷市场获取额外利息。
            </p>

            <div className="glass mt-8 p-7">
              <div className="relative z-10">
                <div className="text-xs uppercase tracking-[0.3em] text-black/60">当前收益节奏</div>
                <div className="mt-3 text-3xl font-semibold">+10 ZZ / Block</div>

                <div className="mt-6 grid gap-3 md:grid-cols-3">
                  <div className="rounded-2xl border border-white/60 bg-white/60 p-4 text-center">
                    <div className="text-[11px] uppercase tracking-[0.25em] text-black/50">TVL</div>
                    <div className="mt-2 text-lg font-semibold">1,284 ETH</div>
                  </div>
                  <div className="rounded-2xl border border-white/60 bg-white/60 p-4 text-center">
                    <div className="text-[11px] uppercase tracking-[0.25em] text-black/50">APR</div>
                    <div className="mt-2 text-lg font-semibold">18.6%</div>
                  </div>
                  <div className="rounded-2xl border border-white/60 bg-white/60 p-4 text-center">
                    <div className="text-[11px] uppercase tracking-[0.25em] text-black/50">Accrual</div>
                    <div className="mt-2 text-lg font-semibold">1.2s</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="neu reveal delay-2 p-7">
            <div className="text-xs uppercase tracking-[0.3em] text-black/70">Stake Console</div>
            <div className="mt-5 flex items-center justify-between rounded-2xl px-4 py-3 neu-input">
              <input
                className="w-24 bg-transparent text-lg outline-none"
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
                placeholder="0.0"
              />
              <span className="font-semibold">ETH</span>
            </div>

            <div className="mt-5 grid grid-cols-2 gap-3">
              <button
                className="neu-btn rounded-2xl px-4 py-3 text-sm font-semibold transition"
                onClick={handleStake}
                disabled={!isConnected || !hasConfig || pendingAction}
              >
                {pendingAction === "stake" ? "Staking..." : "Stake"}
              </button>
              <button
                className="neu-btn rounded-2xl px-4 py-3 text-sm font-semibold transition"
                onClick={handleClaim}
                disabled={!isConnected || !hasConfig || pendingAction}
              >
                {pendingAction === "claim" ? "Claiming..." : "Claim"}
              </button>
            </div>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <button
                className="neu-btn rounded-2xl px-4 py-3 text-sm font-semibold transition"
                onClick={handleUnstake}
                disabled={!isConnected || !hasConfig || pendingAction}
              >
                {pendingAction === "unstake" ? "Unstaking..." : "Unstake"}
              </button>
              <button className="neu-btn rounded-2xl px-4 py-3 text-sm font-semibold transition" disabled>
                History
              </button>
            </div>

            <div className="mt-5 text-xs text-black/60">自动将 ETH 转为 WETH 并存入借贷市场</div>
            <div className="mt-3 text-xs text-black/60">{hasConfig ? "" : "请先配置 StakingPool 地址"}</div>
          </div>
        </section>

        <section className="mt-10 grid gap-4 md:grid-cols-3">
          <div className="card-soft reveal delay-1 p-5">
            <div className="text-xs uppercase tracking-[0.3em] text-black/60">Wallet</div>
            <div className="mt-3 text-sm text-black/70">地址</div>
            <div className="mt-1 text-xs text-black/50">
              {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : "未连接"}
            </div>
            <div className="mt-3 text-sm text-black/70">ETH 余额</div>
            <div className="mt-1 text-lg font-semibold">
              {ethBalance.data ? `${Number(formatEther(ethBalance.data.value)).toFixed(4)} ETH` : "-"}
            </div>
          </div>
          <div className="card-soft reveal delay-2 p-5">
            <div className="text-xs uppercase tracking-[0.3em] text-black/60">Staked</div>
            <div className="mt-3 text-lg font-semibold">{formattedStake} ETH</div>
            <div className="mt-4 text-sm text-black/70">待领取</div>
            <div className="mt-1 text-lg font-semibold">{formattedEarned} ZZ</div>
            {chain?.id === 31337 && formattedEarned === "0" && formattedStake !== "0" && (
              <div className="mt-2 text-[11px] text-black/45">
                Anvil 仅在有交易时出块，未出块时待领取会保持为 0
              </div>
            )}
          </div>
          <div className="card-soft reveal delay-3 p-5">
            <div className="text-xs uppercase tracking-[0.3em] text-black/60">Rewards</div>
            <div className="mt-3 text-lg font-semibold">{formattedZZ} ZZ</div>
            <div className="mt-4 text-sm text-black/70">Network</div>
            <div className="mt-1 text-xs text-black/60">
              {chain ? `${chain.name} (${chain.id})` : "-"}
            </div>
          </div>
        </section>

        <section className="mt-10 grid gap-4 md:grid-cols-3">
          <div className="card-soft reveal delay-1 p-5">
            <div className="text-xs uppercase tracking-[0.3em] text-black/60">Lending Status</div>
            <div className="mt-3 text-sm text-black/70">Pool Deposit</div>
            <div className="mt-1 text-lg font-semibold">
              {hasLendingConfig ? `${formattedPoolAToken} ${poolATokenSymbol.data || "aToken"}` : "-"}
            </div>
            <div className="mt-3 text-sm text-black/70">Interest Accrued</div>
            <div className="mt-1 text-lg font-semibold">{hasLendingConfig ? `${formattedInterest} WETH` : "-"}</div>
            <div className="mt-3 text-xs text-black/60">
              {hasLendingConfig ? "统计来自 StakingPool 合约地址" : "请配置 aToken 地址"}
            </div>
            <div className="mt-4">
              <button
                className="neu-btn rounded-2xl px-4 py-2 text-xs font-semibold transition"
                onClick={handleAccrue}
                disabled={!hasMockAccrue || pendingAction}
              >
                {pendingAction === "accrue" ? "Accruing..." : "模拟利息 +0.5 WETH"}
              </button>
            </div>
          </div>
          <div className="card-soft reveal delay-2 p-5">
            <div className="text-xs uppercase tracking-[0.3em] text-black/60">Vault Status</div>
            <p className="mt-2 text-sm text-black/65">
              ETH 正在借贷市场中产生额外收益，ZZ 激励每区块更新。
            </p>
            <div className="mt-4 text-xs uppercase tracking-[0.25em] text-black/50">Total Staked</div>
            <div className="mt-2 text-lg font-semibold">{formattedTotalStaked} ETH</div>
          </div>
          <div className="card-soft reveal delay-3 p-5">
            <div className="text-xs uppercase tracking-[0.3em] text-black/60">Status</div>
            <p className="mt-2 text-sm text-black/65">{status || "准备就绪"}</p>
            <div className="mt-4 text-xs uppercase tracking-[0.25em] text-black/50">Recent Activity</div>
              <div className="mt-2 space-y-2 text-xs text-black/70">
              {activityStatus === "idle" && (
                <div className="text-black/50">连接钱包后可读取链上记录</div>
              )}
              {activityStatus === "loading" && <div className="text-black/50">读取链上记录中...</div>}
              {activityStatus === "error" && <div className="text-black/50">链上记录读取失败</div>}
              {activityStatus === "ready" && activity.length === 0 && (
                <div className="text-black/50">暂无记录</div>
              )}
              {activity.map((item) => (
                <div key={item.id} className="rounded-xl border border-black/5 bg-white/60 px-3 py-2">
                  <div className="flex items-center justify-between">
                    <span>{`${item.type} ${item.amount}`}</span>
                    <span className="text-black/45">{item.time}</span>
                  </div>
                  <div className="mt-1 flex items-center justify-between text-[10px] text-black/45">
                    <span>{item.user ? `${item.user.slice(0, 6)}...${item.user.slice(-4)}` : "-"}</span>
                    <span>{item.hash ? `${item.hash.slice(0, 6)}...${item.hash.slice(-4)}` : "-"}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>
    </>
  );
}
