import { useMemo } from "react";
import { useReadContract, useReadContracts } from "wagmi";
import { MARKET_ADDRESS } from "../web3/addresses";
import { marketAbi } from "../web3/abi";

export type Listing = {
  seller: `0x${string}`;
  nft: `0x${string}`;
  tokenId: bigint;
  payToken: `0x${string}`;
  price: bigint;
  active: boolean;
};

export function useListings(max = 50) {
  // 1) 读 nextListingId
  const nextId = useReadContract({
    address: MARKET_ADDRESS,
    abi: marketAbi,
    functionName: "nextListingId",
  });

  // 2) 计算要读取的数量（最多 max 条）
  const count = useMemo(() => {
    const n = typeof nextId.data === "bigint" ? Number(nextId.data) : 0;
    return Math.min(n, max);
  }, [nextId.data, max]);

  // 3) 构造批量 calls（纯数据，不是 hooks）
  const contracts = useMemo(() => {
    return Array.from({ length: count }, (_, i) => ({
      address: MARKET_ADDRESS,
      abi: marketAbi,
      functionName: "listings" as const,
      args: [BigInt(i)] as const,
    }));
  }, [count]);

  // 4) 批量读取 listings
  const listingsReads = useReadContracts({
    contracts,
    // allowFailure: true 让某些读失败也不会炸（可选）
    allowFailure: true,
    query: {
      // nextId 还没回来时，count=0 → contracts=[]，这里也不会触发 hook 数量变化
      enabled: contracts.length > 0,
    },
  });

  const listings = useMemo(() => {
    // wagmi 返回的结构是 [{ result }, { result }...]
    return (listingsReads.data ?? [])
      .map((item, idx) => {
        const res = (item as any)?.result as any[] | undefined;
        if (!res) return null;

        const [seller, nft, tokenId, payToken, price, active] = res;
        return {
          id: BigInt(idx),
          seller,
          nft,
          tokenId,
          payToken,
          price,
          active,
        } as { id: bigint } & Listing;
      })
      .filter(Boolean) as Array<{ id: bigint } & Listing>;
  }, [listingsReads.data]);

  return { nextId, listings, listingsReads };
}
