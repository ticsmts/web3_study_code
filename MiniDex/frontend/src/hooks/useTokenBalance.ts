import { useReadContract, useAccount } from 'wagmi';
import { Address, formatUnits } from 'viem';
import erc20Abi from '../lib/abis/ERC20.json';

export function useTokenBalance(tokenAddress?: Address) {
  const { address } = useAccount();

  const { data, isLoading, isError, refetch } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: {
      enabled: !!address && !!tokenAddress,
    },
  });

  const formattedBalance = data ? formatUnits(data as bigint, 18) : '0';

  return {
    balance: data as bigint | undefined,
    formattedBalance,
    isLoading,
    isError,
    refetch,
  };
}
