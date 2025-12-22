import { useWatchContractEvent } from "wagmi";
import { MARKET_ADDRESS } from "../web3/addresses";
import { marketAbi } from "../web3/abi";

export function useMarketEvents(onChange: () => void) {
  useWatchContractEvent({
    address: MARKET_ADDRESS,
    abi: marketAbi,
    eventName: "Listed",
    onLogs: () => onChange(),
  });

  useWatchContractEvent({
    address: MARKET_ADDRESS,
    abi: marketAbi,
    eventName: "Bought",
    onLogs: () => onChange(),
  });
}
