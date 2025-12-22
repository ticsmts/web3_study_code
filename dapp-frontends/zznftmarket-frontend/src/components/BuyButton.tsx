import { useAccount, usePublicClient, useReadContract, useWriteContract } from "wagmi";
import { formatEther } from "viem";
import { MARKET_ADDRESS } from "../web3/addresses";
import { erc20Abi, marketAbi, erc20ReadAbi } from "../web3/abi";

export default function BuyButtons({
  listingId,
  price,
  payToken,
  active,
  disabled,
}: {
  listingId: bigint;
  price: bigint;
  payToken: `0x${string}`;
  active: boolean;
  disabled?: boolean;
}) {
  const { address, isConnected } = useAccount();
  const publicClient = usePublicClient();
  const { writeContractAsync, isPending } = useWriteContract();

  // 1) 读 allowance / balance（可验证）
  const allowance = useReadContract({
    address: payToken,
    abi: erc20ReadAbi,
    functionName: "allowance",
    args: address ? [address, MARKET_ADDRESS] : undefined,
    query: { enabled: !!address },
  });

  const balance = useReadContract({
    address: payToken,
    abi: erc20ReadAbi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  });

  const allow = (allowance.data as bigint | undefined) ?? 0n;
  const bal = (balance.data as bigint | undefined) ?? 0n;

  const allowanceEnough = allow >= price;
  const balanceEnough = bal >= price;

  // 2) Approve 按钮：只 approve
  async function onApprove() {
    if (!address) throw new Error("Not connected");

    const hash = await writeContractAsync({
      address: payToken,
      abi: erc20Abi,
      functionName: "approve",
      args: [MARKET_ADDRESS, price],
    });

    // ✅ 等确认，避免你马上点 buy 仍然读到旧 allowance
    await publicClient.waitForTransactionReceipt({ hash });

    // ✅ 刷新 allowance（让 UI 立刻更新）
    await allowance.refetch();
  }

  // 3) Buy 按钮：只 buy
  async function onBuy() {
    if (!address) throw new Error("Not connected");

    // 这里再做一道防呆：不够就直接提示（避免白花 gas）
    if (!allowanceEnough) throw new Error("Allowance not enough, please approve first");
    if (!balanceEnough) throw new Error("Balance not enough");

    const hash = await writeContractAsync({
      address: MARKET_ADDRESS,
      abi: marketAbi,
      functionName: "buyNFT",
      args: [listingId, price],
    });

    await publicClient.waitForTransactionReceipt({ hash });
  }

  const approveDisabled =
    !isConnected || isPending || disabled || !active || !balanceEnough; // 余额不足就不让 approve/buy 都行（可选）

  const buyDisabled =
    !isConnected || isPending || disabled || !active || !allowanceEnough || !balanceEnough;

  return (
    <div className="mt-3 space-y-2">
      <div className="text-xs text-zinc-500">
        Price: {formatEther(price)} | Allowance: {formatEther(allow)} | Balance: {formatEther(bal)}
      </div>

      {!balanceEnough && (
        <div className="text-xs text-red-600">
          余额不足：需要至少 {formatEther(price)} TOKEN
        </div>
      )}

      <div className="grid grid-cols-2 gap-2">
        <button
          disabled={approveDisabled || allowanceEnough}
          onClick={onApprove}
          className="rounded-xl bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700 disabled:opacity-50"
        >
          {allowanceEnough ? "Approved" : "Approve"}
        </button>

        <button
          disabled={buyDisabled}
          onClick={onBuy}
          className="rounded-xl bg-emerald-600 px-4 py-2 text-white hover:bg-emerald-700 disabled:opacity-50"
        >
          Buy
        </button>
      </div>
    </div>
  );
}
