import { useWriteContract, useAccount, usePublicClient } from 'wagmi';
import { Address, parseUnits } from 'viem';
import routerAbi from '../lib/abis/UniswapV2Router02.json';
import erc20Abi from '../lib/abis/ERC20.json';
import { CONTRACTS } from '../lib/contracts';

export function useSwap() {
  const { address } = useAccount();
  const { writeContractAsync: writeContract } = useWriteContract();
  const publicClient = usePublicClient();

  const swap = async (
    amountIn: string,
    amountOutMin: string,
    fromToken: Address,
    toToken: Address
  ) => {
    if (!address) throw new Error('Wallet not connected');
    if (!publicClient) throw new Error('Public client not available');

    const parsedAmountIn = parseUnits(amountIn, 18);
    const parsedAmountOutMin = parseUnits(amountOutMin, 18);
    const path = [fromToken, toToken];
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 60 * 20); // 20 minutes

    // 1. Check existing allowance
    const allowance = await publicClient.readContract({
      address: fromToken,
      abi: erc20Abi,
      functionName: 'allowance',
      args: [address, CONTRACTS.router],
    }) as bigint;

    // 2. Approve if needed
    if (allowance < parsedAmountIn) {
      const approveTxHash = await writeContract({
        address: fromToken,
        abi: erc20Abi,
        functionName: 'approve',
        args: [CONTRACTS.router, parsedAmountIn],
      });

      // Wait for approval transaction to be mined
      await publicClient.waitForTransactionReceipt({ hash: approveTxHash });
    }

    // 3. Execute swap
    return writeContract({
      address: CONTRACTS.router,
      abi: routerAbi,
      functionName: 'swapExactTokensForTokens',
      args: [parsedAmountIn, parsedAmountOutMin, path, address, deadline],
    });
  };

  return { swap };
}
