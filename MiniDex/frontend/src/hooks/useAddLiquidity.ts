import { useWriteContract, useAccount, usePublicClient } from 'wagmi';
import { Address, parseUnits } from 'viem';
import routerAbi from '../lib/abis/UniswapV2Router02.json';
import erc20Abi from '../lib/abis/ERC20.json';
import { CONTRACTS } from '../lib/contracts';

export function useAddLiquidity() {
    const { address } = useAccount();
    const { writeContractAsync: writeContract } = useWriteContract();
    const publicClient = usePublicClient();

    const addLiquidity = async (
        tokenA: Address,
        tokenB: Address,
        amountA: string,
        amountB: string,
        slippage: number = 0.5 // 默认0.5%滑点
    ) => {
        if (!address) throw new Error('Wallet not connected');
        if (!publicClient) throw new Error('Public client not available');

        const parsedAmountA = parseUnits(amountA, 18);
        const parsedAmountB = parseUnits(amountB, 18);

        // 计算最小接受金额 (考虑滑点)
        const slippageMultiplier = BigInt(Math.floor((1 - slippage / 100) * 10000));
        const amountAMin = (parsedAmountA * slippageMultiplier) / 10000n;
        const amountBMin = (parsedAmountB * slippageMultiplier) / 10000n;

        const deadline = BigInt(Math.floor(Date.now() / 1000) + 60 * 20); // 20分钟

        // 1. 检查并授权 TokenA
        const allowanceA = await publicClient.readContract({
            address: tokenA,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [address, CONTRACTS.router],
        }) as bigint;

        if (allowanceA < parsedAmountA) {
            const approveTxA = await writeContract({
                address: tokenA,
                abi: erc20Abi,
                functionName: 'approve',
                args: [CONTRACTS.router, parsedAmountA],
            });
            await publicClient.waitForTransactionReceipt({ hash: approveTxA });
        }

        // 2. 检查并授权 TokenB
        const allowanceB = await publicClient.readContract({
            address: tokenB,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [address, CONTRACTS.router],
        }) as bigint;

        if (allowanceB < parsedAmountB) {
            const approveTxB = await writeContract({
                address: tokenB,
                abi: erc20Abi,
                functionName: 'approve',
                args: [CONTRACTS.router, parsedAmountB],
            });
            await publicClient.waitForTransactionReceipt({ hash: approveTxB });
        }

        // 3. 添加流动性
        return writeContract({
            address: CONTRACTS.router,
            abi: routerAbi,
            functionName: 'addLiquidity',
            args: [
                tokenA,
                tokenB,
                parsedAmountA,
                parsedAmountB,
                amountAMin,
                amountBMin,
                address,
                deadline,
            ],
        });
    };

    return { addLiquidity };
}
