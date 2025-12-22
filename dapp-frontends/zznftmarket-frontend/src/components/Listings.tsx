import { formatEther } from "viem";
import { useListings } from "../hooks/useListings";
import BuyButton from "./BuyButton";

export default function Listings() {
  const { nextId, listings, listingsReads } = useListings(50);

  const loading = nextId.isLoading || listingsReads.isLoading;

  return (
    <div className="rounded-2xl border bg-white p-6 shadow-sm">
      <div className="flex items-end justify-between">
        <div>
          <h2 className="text-lg font-semibold">Listings</h2>
          <p className="text-sm text-zinc-500">
            nextListingId:{" "}
            {typeof nextId.data === "bigint" ? nextId.data.toString() : "-"}
          </p>
        </div>
      </div>

      <div className="mt-4">
        {loading && <div className="text-sm text-zinc-500">Loading...</div>}
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {listings.map((l) => (
          <div
            key={l.id.toString()}
            className="rounded-2xl border p-4 hover:shadow-sm transition"
          >
            <div className="text-sm text-zinc-500">
              Listing #{l.id.toString()}
            </div>

            <div className="mt-2 text-sm space-y-1">
              <div>
                <span className="text-zinc-500">TokenId:</span>{" "}
                {l.tokenId.toString()}
              </div>
              <div className="truncate">
                <span className="text-zinc-500">Seller:</span> {l.seller}
              </div>
              <div className="truncate">
                <span className="text-zinc-500">NFT:</span> {l.nft}
              </div>
              <div className="truncate">
                <span className="text-zinc-500">PayToken:</span> {l.payToken}
              </div>
              <div>
                <span className="text-zinc-500">Price:</span>{" "}
                {formatEther(l.price)}
              </div>

              <div className="pt-2">
                {l.active ? (
                  <span className="inline-flex rounded-full bg-emerald-50 px-2 py-1 text-xs text-emerald-700">
                    Active
                  </span>
                ) : (
                  <span className="inline-flex rounded-full bg-zinc-100 px-2 py-1 text-xs text-zinc-600">
                    Sold
                  </span>
                )}
              </div>

              {/* ✅ 关键：BuyButton 放在每个 listing 卡片内部 */}
              {l.active && (
                <BuyButton
                  listingId={l.id}
                  price={l.price}
                  payToken={l.payToken}
                  active={l.active}
                />
              )}
            </div>
          </div>
        ))}

        {!loading && listings.length === 0 && (
          <div className="text-sm text-zinc-500">No listings yet.</div>
        )}
      </div>
    </div>
  );
}
