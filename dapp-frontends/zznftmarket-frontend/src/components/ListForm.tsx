import { useState } from "react";
import { parseEther } from "viem";
import { useAccount, useWriteContract } from "wagmi";
import { MARKET_ADDRESS, NFT_ADDRESS, TOKEN_ADDRESS } from "../web3/addresses";
import { erc721Abi, marketAbi } from "../web3/abi";

export default function ListForm() {
  const { isConnected } = useAccount();
  const { writeContractAsync, isPending } = useWriteContract();

  const [tokenId, setTokenId] = useState("1");
  const [price, setPrice] = useState("1000"); // token 单位（假设 18 decimals）

  async function onList() {
    const tid = BigInt(tokenId);
    const p = parseEther(price);

    // 1) approve NFT 给 market
    await writeContractAsync({
      address: NFT_ADDRESS,
      abi: erc721Abi,
      functionName: "approve",
      args: [MARKET_ADDRESS, tid],
    });

    // 2) 调 market.list
    await writeContractAsync({
      address: MARKET_ADDRESS,
      abi: marketAbi,
      functionName: "list",
      args: [NFT_ADDRESS, tid, TOKEN_ADDRESS, p],
    });
  }

  return (
    <div className="rounded-2xl border bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold">List an NFT</h2>
      <p className="mt-1 text-sm text-zinc-500">
        卖家账号：先 approve，再 list。请确保当前连接的钱包拥有该 tokenId。
      </p>

      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        <label className="grid gap-1">
          <span className="text-sm text-zinc-600">Token ID</span>
          <input
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            className="rounded-xl border px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-200"
          />
        </label>
        <label className="grid gap-1">
          <span className="text-sm text-zinc-600">Price (TOKEN)</span>
          <input
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            className="rounded-xl border px-3 py-2 outline-none focus:ring-2 focus:ring-indigo-200"
          />
        </label>
      </div>

      <button
        disabled={!isConnected || isPending}
        onClick={onList}
        className="mt-4 inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2 text-white hover:bg-indigo-700 disabled:opacity-50"
      >
        {isPending ? "Sending..." : "Approve & List"}
      </button>

      <div className="mt-3 text-xs text-zinc-500">
        验证点：交易成功后 nextListingId 增加，并出现新的 Active listing。
      </div>
    </div>
  );
}
