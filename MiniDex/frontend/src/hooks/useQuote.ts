import { useReadContract } from 'wagmi';
import { Address, parseUnits, formatUnits } from 'viem';
import routerAbi from '../lib/abis/UniswapV2Router02.json';
import { CONTRACTS } from '../lib/contracts';

export function useQuote(
  amountIn: string,
  fromToken?: Address,
  toToken?: Address
) {
  const path = fromToken && toToken ? [fromToken, toToken] : [];
  const parsedAmountIn = amountIn ? parseUnits(amountIn, 18) : 0n;

  const { data, isLoading, isError } = useReadContract({
    address: CONTRACTS.router,
    abi: routerAbi,
    functionName: 'getAmountsOut',
    args: parsedAmountIn > 0n && path.length === 2 ? [parsedAmountIn, path] : undefined,
    query: {
      enabled: parsedAmountIn > 0n && path.length === 2,
    },
  });

  const amounts = data as bigint[] | undefined;
  const amountOut = amounts && amounts.length > 0 ? amounts[amounts.length - 1] : 0n;
  const formattedAmountOut = amountOut > 0n ? formatUnits(amountOut, 18) : '';

  return {
    amountOut,
    formattedAmountOut,
    isLoading,
    isError,
  };
}
