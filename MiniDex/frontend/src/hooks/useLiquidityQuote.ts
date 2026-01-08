import { useEffect, useState, useCallback } from 'react';
import { usePublicClient } from 'wagmi';
import { Address, formatUnits, parseUnits } from 'viem';
import { CONTRACTS } from '../lib/contracts';

// Factory ABI
const FACTORY_ABI = [
    {
        type: 'function',
        name: 'getPair',
        inputs: [
            { name: 'tokenA', type: 'address' },
            { name: 'tokenB', type: 'address' },
        ],
        outputs: [{ name: 'pair', type: 'address' }],
        stateMutability: 'view',
    },
] as const;

// Pair ABI
const PAIR_ABI = [
    {
        type: 'function',
        name: 'getReserves',
        inputs: [],
        outputs: [
            { name: 'reserve0', type: 'uint112' },
            { name: 'reserve1', type: 'uint112' },
            { name: 'blockTimestampLast', type: 'uint32' },
        ],
        stateMutability: 'view',
    },
    {
        type: 'function',
        name: 'token0',
        inputs: [],
        outputs: [{ type: 'address' }],
        stateMutability: 'view',
    },
    {
        type: 'function',
        name: 'totalSupply',
        inputs: [],
        outputs: [{ type: 'uint256' }],
        stateMutability: 'view',
    },
] as const;

interface PoolInfo {
    exists: boolean;
    pairAddress: Address | null;
    reserveA: bigint;
    reserveB: bigint;
    totalSupply: bigint;
    shareOfPool: string;
    priceAperB: string;
    priceBperA: string;
}

export function useLiquidityQuote(
    tokenA?: Address,
    tokenB?: Address,
    amountA?: string,
    amountB?: string
) {
    const publicClient = usePublicClient();
    const [poolInfo, setPoolInfo] = useState<PoolInfo | null>(null);
    const [optimalAmountB, setOptimalAmountB] = useState<string>('');
    const [optimalAmountA, setOptimalAmountA] = useState<string>('');
    const [isLoading, setIsLoading] = useState(false);
    const [estimatedLPTokens, setEstimatedLPTokens] = useState<string>('');

    const fetchPoolInfo = useCallback(async () => {
        if (!publicClient || !tokenA || !tokenB) {
            setPoolInfo(null);
            return;
        }

        setIsLoading(true);
        try {
            // 获取交易对地址
            const pairAddress = await publicClient.readContract({
                address: CONTRACTS.factory,
                abi: FACTORY_ABI,
                functionName: 'getPair',
                args: [tokenA, tokenB],
            }) as Address;

            if (pairAddress === '0x0000000000000000000000000000000000000000') {
                setPoolInfo({
                    exists: false,
                    pairAddress: null,
                    reserveA: 0n,
                    reserveB: 0n,
                    totalSupply: 0n,
                    shareOfPool: '100',
                    priceAperB: '0',
                    priceBperA: '0',
                });
                return;
            }

            // 获取储备量和token0
            const [reserves, token0, totalSupply] = await Promise.all([
                publicClient.readContract({
                    address: pairAddress,
                    abi: PAIR_ABI,
                    functionName: 'getReserves',
                }) as Promise<[bigint, bigint, number]>,
                publicClient.readContract({
                    address: pairAddress,
                    abi: PAIR_ABI,
                    functionName: 'token0',
                }) as Promise<Address>,
                publicClient.readContract({
                    address: pairAddress,
                    abi: PAIR_ABI,
                    functionName: 'totalSupply',
                }) as Promise<bigint>,
            ]);

            const [reserve0, reserve1] = reserves;
            const isTokenAFirst = tokenA.toLowerCase() === token0.toLowerCase();
            const reserveA = isTokenAFirst ? reserve0 : reserve1;
            const reserveB = isTokenAFirst ? reserve1 : reserve0;

            const priceAperB = Number(reserveB) / Number(reserveA);
            const priceBperA = Number(reserveA) / Number(reserveB);

            setPoolInfo({
                exists: true,
                pairAddress,
                reserveA,
                reserveB,
                totalSupply,
                shareOfPool: '0',
                priceAperB: priceAperB.toFixed(6),
                priceBperA: priceBperA.toFixed(6),
            });
        } catch (error) {
            console.error('Error fetching pool info:', error);
            setPoolInfo(null);
        } finally {
            setIsLoading(false);
        }
    }, [publicClient, tokenA, tokenB]);

    // 当 tokenA 或 tokenB 变化时获取池子信息
    useEffect(() => {
        fetchPoolInfo();
    }, [fetchPoolInfo]);

    // 当 amountA 变化时计算 optimal amountB
    useEffect(() => {
        if (!poolInfo || !amountA || parseFloat(amountA) <= 0) {
            setOptimalAmountB('');
            setEstimatedLPTokens('');
            return;
        }

        if (!poolInfo.exists || poolInfo.reserveA === 0n) {
            // 新池子，不需要计算最优值
            setOptimalAmountB('');
            return;
        }

        try {
            const parsedAmountA = parseUnits(amountA, 18);
            // quote: amountB = amountA * reserveB / reserveA
            const optimalB = (parsedAmountA * poolInfo.reserveB) / poolInfo.reserveA;
            setOptimalAmountB(formatUnits(optimalB, 18));

            // 估算 LP tokens
            // liquidity = min(amountA * totalSupply / reserveA, amountB * totalSupply / reserveB)
            const liquidityFromA = (parsedAmountA * poolInfo.totalSupply) / poolInfo.reserveA;
            const liquidityFromB = (optimalB * poolInfo.totalSupply) / poolInfo.reserveB;
            const estimatedLP = liquidityFromA < liquidityFromB ? liquidityFromA : liquidityFromB;
            setEstimatedLPTokens(formatUnits(estimatedLP, 18));

            // 计算池子份额
            const newTotalSupply = poolInfo.totalSupply + estimatedLP;
            const sharePercent = (Number(estimatedLP) / Number(newTotalSupply)) * 100;
            setPoolInfo(prev => prev ? { ...prev, shareOfPool: sharePercent.toFixed(4) } : null);
        } catch (error) {
            console.error('Error calculating optimal amount:', error);
        }
    }, [amountA, poolInfo?.exists, poolInfo?.reserveA, poolInfo?.reserveB, poolInfo?.totalSupply]);

    // 当 amountB 变化时计算 optimal amountA (反向)
    useEffect(() => {
        if (!poolInfo || !amountB || parseFloat(amountB) <= 0) {
            setOptimalAmountA('');
            return;
        }

        if (!poolInfo.exists || poolInfo.reserveB === 0n) {
            setOptimalAmountA('');
            return;
        }

        try {
            const parsedAmountB = parseUnits(amountB, 18);
            // quote: amountA = amountB * reserveA / reserveB
            const optimalA = (parsedAmountB * poolInfo.reserveA) / poolInfo.reserveB;
            setOptimalAmountA(formatUnits(optimalA, 18));
        } catch (error) {
            console.error('Error calculating optimal amount:', error);
        }
    }, [amountB, poolInfo?.exists, poolInfo?.reserveA, poolInfo?.reserveB]);

    return {
        poolInfo,
        optimalAmountB,
        optimalAmountA,
        estimatedLPTokens,
        isLoading,
        refetch: fetchPoolInfo,
    };
}
