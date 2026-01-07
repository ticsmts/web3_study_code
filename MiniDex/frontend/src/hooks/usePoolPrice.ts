import { useEffect, useState, useCallback } from 'react';
import { usePublicClient, useBlockNumber } from 'wagmi';
import { Address, formatUnits } from 'viem';
import { CONTRACTS } from '@/lib/contracts';

interface PoolReserves {
    reserve0: bigint;
    reserve1: bigint;
    token0: Address;
    token1: Address;
}

interface PriceInfo {
    price: number;           // Price of tokenA in terms of tokenB
    priceFormatted: string;  // Formatted price string
    reserve0: string;        // Formatted reserve0
    reserve1: string;        // Formatted reserve1
    token0Symbol: string;
    token1Symbol: string;
    lastUpdate: number;      // Timestamp of last update
    change24h?: number;      // Price change percentage (mock for now)
}

// Pair ABI for getReserves and token addresses
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
        name: 'token1',
        inputs: [],
        outputs: [{ type: 'address' }],
        stateMutability: 'view',
    },
] as const;

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

export function usePoolPrice(tokenA: Address, tokenB: Address) {
    const [priceInfo, setPriceInfo] = useState<PriceInfo | null>(null);
    const [previousPrice, setPreviousPrice] = useState<number | null>(null);
    const [isLoading, setIsLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const publicClient = usePublicClient();
    const { data: blockNumber } = useBlockNumber({ watch: true });

    const fetchPrice = useCallback(async () => {
        if (!publicClient) return;

        try {
            // Get pair address
            const pairAddress = await publicClient.readContract({
                address: CONTRACTS.factory,
                abi: FACTORY_ABI,
                functionName: 'getPair',
                args: [tokenA, tokenB],
            }) as Address;

            if (pairAddress === '0x0000000000000000000000000000000000000000') {
                setError('Pair does not exist');
                setIsLoading(false);
                return;
            }

            // Get reserves and token addresses
            const [reserves, token0, token1] = await Promise.all([
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
                    functionName: 'token1',
                }) as Promise<Address>,
            ]);

            const [reserve0, reserve1] = reserves;

            // Determine which token is which
            const isToken0First = token0.toLowerCase() === tokenA.toLowerCase();
            const reserveA = isToken0First ? reserve0 : reserve1;
            const reserveB = isToken0First ? reserve1 : reserve0;

            // Calculate price: how much of tokenB per tokenA
            const price = Number(reserveB) / Number(reserveA);

            // Get token symbols
            const token0Symbol = getTokenSymbol(token0);
            const token1Symbol = getTokenSymbol(token1);
            const tokenASymbol = isToken0First ? token0Symbol : token1Symbol;
            const tokenBSymbol = isToken0First ? token1Symbol : token0Symbol;

            // Calculate change from previous price
            let change24h = 0;
            if (previousPrice !== null && previousPrice > 0) {
                change24h = ((price - previousPrice) / previousPrice) * 100;
            }

            // Update previous price for next comparison
            if (priceInfo?.price !== price) {
                setPreviousPrice(priceInfo?.price ?? null);
            }

            setPriceInfo({
                price,
                priceFormatted: price.toFixed(6),
                reserve0: formatUnits(reserve0, 18),
                reserve1: formatUnits(reserve1, 18),
                token0Symbol,
                token1Symbol,
                lastUpdate: Date.now(),
                change24h,
            });
            setError(null);
        } catch (err) {
            console.error('Error fetching pool price:', err);
            setError('Failed to fetch price');
        } finally {
            setIsLoading(false);
        }
    }, [publicClient, tokenA, tokenB, previousPrice, priceInfo?.price]);

    // Fetch price on mount and when block changes
    useEffect(() => {
        fetchPrice();
    }, [fetchPrice, blockNumber]);

    return { priceInfo, isLoading, error, refetch: fetchPrice };
}

// Helper to get token symbol from address
function getTokenSymbol(address: Address): string {
    const lowerAddress = address.toLowerCase();
    if (lowerAddress === CONTRACTS.weth.toLowerCase()) return 'WETH';
    if (lowerAddress === CONTRACTS.usdc.toLowerCase()) return 'USDC';
    if (lowerAddress === CONTRACTS.dai.toLowerCase()) return 'DAI';
    return 'Unknown';
}

// Hook for USDC/WETH price (how much WETH per USDC)
export function useUsdcWethPrice() {
    return usePoolPrice(CONTRACTS.usdc, CONTRACTS.weth);
}

// Hook for WETH/USDC price (how much USDC per WETH)
export function useWethUsdcPrice() {
    return usePoolPrice(CONTRACTS.weth, CONTRACTS.usdc);
}
