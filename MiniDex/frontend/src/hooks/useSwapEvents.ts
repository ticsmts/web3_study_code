import { useEffect, useState, useCallback } from 'react';
import { usePublicClient, useBlockNumber } from 'wagmi';
import { Address, formatUnits, parseAbiItem } from 'viem';
import { CONTRACTS, getTokenByAddress } from '@/lib/contracts';

export interface SwapEvent {
    id: string;
    txHash: string;
    sender: Address;
    to: Address;
    tokenIn: string;
    tokenOut: string;
    amountIn: string;
    amountOut: string;
    timestamp: number;
    blockNumber: bigint;
}

const SWAP_EVENT_ABI = parseAbiItem(
    'event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to)'
);

// Factory ABI for getPair
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

export function useSwapEvents(maxEvents: number = 10) {
    const [events, setEvents] = useState<SwapEvent[]>([]);
    const [isLoading, setIsLoading] = useState(true);
    const [pairAddresses, setPairAddresses] = useState<Address[]>([]);
    const publicClient = usePublicClient();
    const { data: blockNumber } = useBlockNumber({ watch: true });

    // Get pair addresses
    useEffect(() => {
        async function getPairs() {
            if (!publicClient) return;

            try {
                const pairs: Address[] = [];

                // Get WETH/USDC pair
                const wethUsdcPair = await publicClient.readContract({
                    address: CONTRACTS.factory,
                    abi: FACTORY_ABI,
                    functionName: 'getPair',
                    args: [CONTRACTS.weth, CONTRACTS.usdc],
                }) as Address;

                if (wethUsdcPair !== '0x0000000000000000000000000000000000000000') {
                    pairs.push(wethUsdcPair);
                }

                // Get WETH/DAI pair
                const wethDaiPair = await publicClient.readContract({
                    address: CONTRACTS.factory,
                    abi: FACTORY_ABI,
                    functionName: 'getPair',
                    args: [CONTRACTS.weth, CONTRACTS.dai],
                }) as Address;

                if (wethDaiPair !== '0x0000000000000000000000000000000000000000') {
                    pairs.push(wethDaiPair);
                }

                // Get USDC/DAI pair
                const usdcDaiPair = await publicClient.readContract({
                    address: CONTRACTS.factory,
                    abi: FACTORY_ABI,
                    functionName: 'getPair',
                    args: [CONTRACTS.usdc, CONTRACTS.dai],
                }) as Address;

                if (usdcDaiPair !== '0x0000000000000000000000000000000000000000') {
                    pairs.push(usdcDaiPair);
                }

                setPairAddresses(pairs);
            } catch (error) {
                console.error('Error getting pair addresses:', error);
            }
        }

        getPairs();
    }, [publicClient]);

    // Fetch swap events
    const fetchEvents = useCallback(async () => {
        if (!publicClient || pairAddresses.length === 0) {
            setIsLoading(false);
            return;
        }

        try {
            setIsLoading(true);
            const allEvents: SwapEvent[] = [];

            // Get current block
            const currentBlock = await publicClient.getBlockNumber();
            const fromBlock = currentBlock > 100n ? currentBlock - 100n : 0n;

            for (const pairAddress of pairAddresses) {
                // Get token0 and token1 for this pair
                const [token0, token1] = await Promise.all([
                    publicClient.readContract({
                        address: pairAddress,
                        abi: [{ type: 'function', name: 'token0', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' }],
                        functionName: 'token0',
                    }) as Promise<Address>,
                    publicClient.readContract({
                        address: pairAddress,
                        abi: [{ type: 'function', name: 'token1', inputs: [], outputs: [{ type: 'address' }], stateMutability: 'view' }],
                        functionName: 'token1',
                    }) as Promise<Address>,
                ]);

                const logs = await publicClient.getLogs({
                    address: pairAddress,
                    event: SWAP_EVENT_ABI,
                    fromBlock,
                    toBlock: 'latest',
                });

                for (const log of logs) {
                    const { sender, amount0In, amount1In, amount0Out, amount1Out, to } = log.args as {
                        sender: Address;
                        amount0In: bigint;
                        amount1In: bigint;
                        amount0Out: bigint;
                        amount1Out: bigint;
                        to: Address;
                    };

                    // Determine which token was input and which was output
                    let tokenIn: Address, tokenOut: Address, amountIn: bigint, amountOut: bigint;

                    if (amount0In > 0n) {
                        tokenIn = token0;
                        tokenOut = token1;
                        amountIn = amount0In;
                        amountOut = amount1Out;
                    } else {
                        tokenIn = token1;
                        tokenOut = token0;
                        amountIn = amount1In;
                        amountOut = amount0Out;
                    }

                    const tokenInInfo = getTokenByAddress(tokenIn);
                    const tokenOutInfo = getTokenByAddress(tokenOut);

                    allEvents.push({
                        id: `${log.transactionHash}-${log.logIndex}`,
                        txHash: log.transactionHash!,
                        sender,
                        to,
                        tokenIn: tokenInInfo?.symbol || 'Unknown',
                        tokenOut: tokenOutInfo?.symbol || 'Unknown',
                        amountIn: parseFloat(formatUnits(amountIn, 18)).toLocaleString(undefined, { maximumFractionDigits: 6 }),
                        amountOut: parseFloat(formatUnits(amountOut, 18)).toLocaleString(undefined, { maximumFractionDigits: 6 }),
                        timestamp: Date.now(), // We could fetch block timestamp but this is simpler
                        blockNumber: log.blockNumber!,
                    });
                }
            }

            // Sort by block number descending and take max events
            allEvents.sort((a, b) => Number(b.blockNumber - a.blockNumber));
            setEvents(allEvents.slice(0, maxEvents));
        } catch (error) {
            console.error('Error fetching swap events:', error);
        } finally {
            setIsLoading(false);
        }
    }, [publicClient, pairAddresses, maxEvents]);

    // Fetch events when pair addresses change or new block arrives
    useEffect(() => {
        fetchEvents();
    }, [fetchEvents, blockNumber]);

    return { events, isLoading, refetch: fetchEvents };
}
