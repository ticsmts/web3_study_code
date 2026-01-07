import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { Coins, ShoppingCart, Zap, ExternalLink, User, RefreshCw, ArrowRightLeft } from 'lucide-react';
import { ethers } from 'ethers';
import { ROUTER_ADDRESS, WETH_ADDRESS } from '../constants';

// Minimal Router ABI for getAmountsOut
const ROUTER_ABI = [
    "function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts)"
];
const ROUTER_FACTORY_ABI = ["function factory() external view returns (address)"];
const FACTORY_ABI = ["function getPair(address tokenA, address tokenB) external view returns (address pair)"];
const PAIR_ABI = [
    "function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)",
    "function token0() external view returns (address)"
];

const TokenCard = ({ meme, factoryContract, provider }) => {
    const [loading, setLoading] = useState(false);
    const [txHash, setTxHash] = useState(null);
    const [lastAction, setLastAction] = useState(null); // 'mint' | 'dex' | null
    const [dexOutput, setDexOutput] = useState(null);
    const [checkingDex, setCheckingDex] = useState(false);
    const [dexRouterAddress, setDexRouterAddress] = useState(ROUTER_ADDRESS);
    const [dexWethAddress, setDexWethAddress] = useState(WETH_ADDRESS);
    const [gasFallbackUsed, setGasFallbackUsed] = useState(false);
    const [lastLiquidityAdded, setLastLiquidityAdded] = useState(null);
    const [liquidityNote, setLiquidityNote] = useState(null);

    const total = Number(ethers.formatEther(meme.totalSupply));
    const minted = Number(ethers.formatEther(meme.totalMinted));
    const progress = (minted / total) * 100;
    const priceInEth = ethers.formatEther(meme.price);

    // Calculate mint cost: perMint * price / 1e18
    const mintCostWei = (BigInt(meme.perMint) * BigInt(meme.price)) / BigInt(1e18);
    const mintCostEth = ethers.formatEther(mintCostWei);
    const perMintAmount = Number(ethers.formatEther(meme.perMint));

    const buildOverridesWithGas = async (estimateFn, args, baseOverrides) => {
        try {
            const gasEstimate = await estimateFn(...args, baseOverrides);
            let buffered = (gasEstimate * 13n) / 10n;
            if (buffered < 3_000_000n) {
                buffered = 3_000_000n;
            }
            setGasFallbackUsed(false);
            return { ...baseOverrides, gasLimit: buffered };
        } catch (err) {
            console.warn("Gas estimate failed, using fallback gasLimit:", err);
            setGasFallbackUsed(true);
            return { ...baseOverrides, gasLimit: 3_000_000n };
        }
    };

    const getLiquiditySkipReason = async (ethAmountWei) => {
        if (!provider || !dexRouterAddress || !dexWethAddress) {
            return 'Unable to check pool state.';
        }
        try {
            const router = new ethers.Contract(dexRouterAddress, ROUTER_FACTORY_ABI, provider);
            const factoryAddress = await router.factory();
            const factory = new ethers.Contract(factoryAddress, FACTORY_ABI, provider);
            const pairAddress = await factory.getPair(meme.address, dexWethAddress);
            if (!pairAddress || pairAddress === ethers.ZeroAddress) {
                return 'Pair not created; addLiquidity likely failed.';
            }
            const pair = new ethers.Contract(pairAddress, PAIR_ABI, provider);
            const [reserve0, reserve1] = await pair.getReserves();
            const token0 = await pair.token0();
            const token0IsMeme = token0.toLowerCase() === meme.address.toLowerCase();
            const tokenReserve = token0IsMeme ? reserve0 : reserve1;
            const wethReserve = token0IsMeme ? reserve1 : reserve0;
            if (wethReserve === 0n || tokenReserve === 0n) {
                return 'Pool reserves are empty; liquidity not added.';
            }
            const requiredTokens = (ethAmountWei * tokenReserve) / wethReserve;
            if (requiredTokens < BigInt(meme.perMint)) {
                return 'Skipped: required tokens < perMint at current price.';
            }
            return 'Liquidity not added (no LiquidityAdded event).';
        } catch (err) {
            console.warn('Failed to compute liquidity reason:', err);
            return 'Unable to check pool state.';
        }
    };

    useEffect(() => {
        let cancelled = false;
        const loadDexConfig = async () => {
            if (!factoryContract) return;
            try {
                const [routerAddr, wethAddr] = await Promise.all([
                    factoryContract.router(),
                    factoryContract.weth()
                ]);
                if (cancelled) return;
                if (routerAddr && routerAddr !== ethers.ZeroAddress) {
                    setDexRouterAddress(routerAddr);
                }
                if (wethAddr && wethAddr !== ethers.ZeroAddress) {
                    setDexWethAddress(wethAddr);
                }
            } catch (err) {
                console.warn("Failed to load DEX config from factory:", err);
            }
        };

        loadDexConfig();
        return () => {
            cancelled = true;
        };
    }, [factoryContract]);

    // Check DEX output for comparison
    const checkDexPrice = async () => {
        if (!provider || !dexRouterAddress || !dexWethAddress) return;
        try {
            setCheckingDex(true);
            const router = new ethers.Contract(dexRouterAddress, ROUTER_ABI, provider);
            const path = [dexWethAddress, meme.address];
            const amounts = await router.getAmountsOut(mintCostWei, path);
            setDexOutput(amounts[1]);
        } catch (err) {
            console.log("No DEX liquidity yet:", err.message);
            setDexOutput(null);
        } finally {
            setCheckingDex(false);
        }
    };

    // Check DEX price on mount and when meme changes
    useEffect(() => {
        checkDexPrice();
    }, [meme.address, provider, dexRouterAddress, dexWethAddress]);

    const parseError = (err) => {
        const msg = err.message || '';
        if (msg.includes('ExceedsTotalSupply') || msg.includes('0x177e3fc3')) {
            return 'Token supply exhausted. No more minting available.';
        }
        if (msg.includes('ExceedsMaxSupply')) {
            return 'Token has reached maximum supply.';
        }
        if (msg.includes('InsufficientPayment')) {
            return 'Not enough ETH sent for minting.';
        }
        if (msg.includes('MemeNotFound')) {
            return 'Token not found in factory.';
        }
        if (msg.includes('user rejected')) {
            return 'Transaction rejected by user.';
        }
        if (msg.includes('INSUFFICIENT_LIQUIDITY')) {
            return 'No liquidity in DEX pool.';
        }
        return err.reason || err.shortMessage || msg;
    };

    const handleMint = async () => {
        if (!factoryContract) return;
        try {
            setLoading(true);
            setLastAction(null);
            setLastLiquidityAdded(null);
            setLiquidityNote(null);
            setLastLiquidityAdded(null);
            setLiquidityNote(null);
            const overrides = await buildOverridesWithGas(
                factoryContract.mintMeme.estimateGas,
                [meme.address],
                { value: mintCostWei }
            );
            const tx = await factoryContract.mintMeme(meme.address, overrides);
            setTxHash(tx.hash);
            const receipt = await tx.wait();
            setLastAction('mint');
            const liquidityEvent = receipt.logs.find(log => {
                try {
                    const parsed = factoryContract.interface.parseLog(log);
                    return parsed?.name === 'LiquidityAdded';
                } catch { return false; }
            });
            if (liquidityEvent) {
                const parsed = factoryContract.interface.parseLog(liquidityEvent);
                setLastLiquidityAdded({
                    tokenAmount: parsed.args[1],
                    ethAmount: parsed.args[2],
                    liquidity: parsed.args[3],
                });
            } else {
                const projectFeeWei = (mintCostWei * 5n) / 100n;
                const reason = await getLiquiditySkipReason(projectFeeWei);
                setLiquidityNote(reason);
            }
            alert("✅ Mint successful! You minted " + perMintAmount.toLocaleString() + " tokens.");
            checkDexPrice(); // Refresh DEX price after mint
        } catch (err) {
            console.error(err);
            alert("Mint failed: " + parseError(err));
        } finally {
            setLoading(false);
        }
    };

    const handleSmartBuy = async () => {
        if (!factoryContract) return;
        try {
            setLoading(true);
            setLastAction(null);
            setLastLiquidityAdded(null);
            setLiquidityNote(null);
            const overrides = await buildOverridesWithGas(
                factoryContract.buyMeme.estimateGas,
                [meme.address],
                { value: mintCostWei }
            );
            const tx = await factoryContract.buyMeme(meme.address, overrides);
            setTxHash(tx.hash);
            const receipt = await tx.wait();

            // Check which route was used by looking at events
            let usedDex = null;
            const memeBoughtEvent = receipt.logs.find(log => {
                try {
                    const parsed = factoryContract.interface.parseLog(log);
                    return parsed?.name === 'MemeBought';
                } catch { return false; }
            });

            if (memeBoughtEvent) {
                const parsed = factoryContract.interface.parseLog(memeBoughtEvent);
                usedDex = parsed.args[4]; // usedDex is the 5th parameter
                setLastAction(usedDex ? 'dex' : 'mint');
                const tokensReceived = ethers.formatEther(parsed.args[2]);
                alert(`✅ Buy successful via ${usedDex ? 'DEX' : 'Mint'}! You got ${Number(tokensReceived).toLocaleString()} tokens.`);
            } else {
                alert("✅ Buy successful!");
            }
            if (usedDex === true) {
                setLiquidityNote('Smart buy via DEX does not add liquidity.');
            } else {
                const liquidityEvent = receipt.logs.find(log => {
                    try {
                        const parsed = factoryContract.interface.parseLog(log);
                        return parsed?.name === 'LiquidityAdded';
                    } catch { return false; }
                });
                if (liquidityEvent) {
                    const parsed = factoryContract.interface.parseLog(liquidityEvent);
                    setLastLiquidityAdded({
                        tokenAmount: parsed.args[1],
                        ethAmount: parsed.args[2],
                        liquidity: parsed.args[3],
                    });
                } else {
                    const projectFeeWei = (mintCostWei * 5n) / 100n;
                    const reason = await getLiquiditySkipReason(projectFeeWei);
                    setLiquidityNote(reason);
                }
            }
            checkDexPrice(); // Refresh DEX price
        } catch (err) {
            console.error(err);
            alert("Buy failed: " + parseError(err));
        } finally {
            setLoading(false);
        }
    };

    // Calculate comparison
    const dexOutputNum = dexOutput ? Number(ethers.formatEther(dexOutput)) : 0;
    const mintIsBetter = perMintAmount >= dexOutputNum || dexOutputNum === 0;
    const hasDexLiquidity = dexOutput && dexOutputNum > 0;

    return (
        <motion.div
            whileHover={{ y: -5 }}
            className="glass-card p-6 flex flex-col gap-4 overflow-hidden relative group"
        >
            {/* Background decoration */}
            <div className="absolute top-0 right-0 p-8 bg-indigo-500/5 rounded-full -mr-12 -mt-12 group-hover:bg-indigo-500/10 transition-colors" />

            <div className="flex justify-between items-start">
                <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 to-pink-500 flex items-center justify-center shadow-lg">
                        <span className="text-xl font-bold">{meme.symbol[0]}</span>
                    </div>
                    <div>
                        <h3 className="text-xl font-bold">{meme.symbol}</h3>
                        <div className="flex items-center gap-1 text-xs text-gray-500">
                            <User className="w-3 h-3" />
                            <span>{meme.creator.slice(0, 6)}...{meme.creator.slice(-4)}</span>
                        </div>
                    </div>
                </div>
                <div className="text-right">
                    <span className="text-xs text-gray-500 uppercase tracking-widest block mb-1">Price/Token</span>
                    <span className="text-lg font-mono font-bold text-indigo-400">{Number(priceInEth).toFixed(6)} ETH</span>
                </div>
            </div>

            <div className="space-y-2">
                <div className="flex justify-between text-xs font-medium">
                    <span className="text-gray-400">Mint Progress</span>
                    <span className="text-indigo-300">{progress.toFixed(1)}%</span>
                </div>
                <div className="progress-container">
                    <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${progress}%` }}
                        className="progress-fill"
                    />
                </div>
                <div className="flex justify-between text-[10px] text-gray-500 font-mono">
                    <span>{minted.toLocaleString()} MINTED</span>
                    <span>{total.toLocaleString()} MAX</span>
                </div>
            </div>

            {/* Price Comparison Panel */}
            <div className="bg-white/5 rounded-lg p-3 space-y-2">
                <div className="flex justify-between items-center text-xs">
                    <span className="text-gray-400">For {Number(mintCostEth).toFixed(4)} ETH you get:</span>
                    <button
                        onClick={checkDexPrice}
                        disabled={checkingDex}
                        className="text-indigo-400 hover:text-indigo-300 p-1"
                        title="Refresh DEX price"
                    >
                        <RefreshCw className={`w-3 h-3 ${checkingDex ? 'animate-spin' : ''}`} />
                    </button>
                </div>

                <div className="grid grid-cols-2 gap-2 text-xs">
                    {/* Mint Option */}
                    <div className={`p-2 rounded-lg border ${mintIsBetter ? 'border-green-500/50 bg-green-500/10' : 'border-white/10'}`}>
                        <div className="flex items-center gap-1 text-gray-400 mb-1">
                            <Zap className="w-3 h-3" />
                            <span>Mint</span>
                            {mintIsBetter && <span className="text-green-400 text-[10px]">✓ Better</span>}
                        </div>
                        <div className="font-mono text-green-300">{perMintAmount.toLocaleString()}</div>
                    </div>

                    {/* DEX Option */}
                    <div className={`p-2 rounded-lg border ${!mintIsBetter && hasDexLiquidity ? 'border-green-500/50 bg-green-500/10' : 'border-white/10'}`}>
                        <div className="flex items-center gap-1 text-gray-400 mb-1">
                            <ArrowRightLeft className="w-3 h-3" />
                            <span>DEX</span>
                            {!mintIsBetter && hasDexLiquidity && <span className="text-green-400 text-[10px]">✓ Better</span>}
                        </div>
                        <div className="font-mono text-blue-300">
                            {hasDexLiquidity ? dexOutputNum.toLocaleString(undefined, {maximumFractionDigits: 2}) : 'No liquidity'}
                        </div>
                    </div>
                </div>
            </div>

            {/* Action Buttons */}
            <div className="grid grid-cols-2 gap-3">
                <button
                    onClick={handleMint}
                    disabled={loading || progress >= 100 || !factoryContract}
                    className="glass-button p-3 rounded-xl border border-white/5 flex items-center justify-center gap-2 hover:bg-white/5 transition-all active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed"
                    title={`Direct Mint: ${perMintAmount.toLocaleString()} tokens for ${mintCostEth} ETH`}
                >
                    <Zap className="w-4 h-4 text-yellow-400" />
                    <span className="font-semibold text-sm">Mint</span>
                </button>
                <button
                    onClick={handleSmartBuy}
                    disabled={loading || !factoryContract || (progress >= 100 && !hasDexLiquidity)}
                    className="btn-primary p-3 rounded-xl flex items-center justify-center gap-2 text-sm shadow-none"
                    title={`Smart Buy: Auto-choose ${mintIsBetter ? 'Mint' : 'DEX'} (better price)`}
                >
                    <ShoppingCart className="w-4 h-4" />
                    <span className="font-semibold">Smart Buy</span>
                </button>
            </div>
            {gasFallbackUsed && (
                <div className="text-[10px] text-center text-amber-300/90">
                    Gas estimate failed; using fallback gas limit.
                </div>
            )}
            {lastLiquidityAdded && (
                <div className="text-[10px] text-center text-emerald-300/90">
                    Liquidity added: {Number(ethers.formatEther(lastLiquidityAdded.tokenAmount)).toLocaleString()} tokens + {Number(ethers.formatEther(lastLiquidityAdded.ethAmount)).toFixed(4)} WETH, LP {Number(ethers.formatEther(lastLiquidityAdded.liquidity)).toFixed(6)}
                </div>
            )}
            {liquidityNote && (
                <div className="text-[10px] text-center text-amber-300/90">
                    {liquidityNote}
                </div>
            )}

            {/* Last Action Result */}
            {lastAction && (
                <div className={`text-xs text-center py-1 px-2 rounded ${lastAction === 'dex' ? 'bg-blue-500/20 text-blue-300' : 'bg-yellow-500/20 text-yellow-300'}`}>
                    Last purchase: via {lastAction === 'dex' ? '🔄 DEX Swap' : '⚡ Factory Mint'}
                </div>
            )}

            {txHash && (
                <a
                    href={`https://etherscan.io/tx/${txHash}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-[10px] text-indigo-400 flex items-center gap-1 hover:underline"
                >
                    <ExternalLink className="w-2 h-2" />
                    View on Explorer
                </a>
            )}
        </motion.div>
    );
};

export default TokenCard;
