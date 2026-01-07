import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
    Rocket,
    Wallet,
    Plus,
    TrendingUp,
    Coins,
    PieChart,
    ArrowRight,
    ShieldCheck,
    RefreshCw,
    Info
} from 'lucide-react';
import { useWeb3 } from './hooks/useWeb3';
import { ethers } from 'ethers';
import { FACTORY_ADDRESS } from './constants';

// Components
import TokenCard from './components/TokenCard';
import DeployModal from './components/DeployModal';

function App() {
    const { account, connectWallet, factoryContract, loading, error, provider } = useWeb3();
    const [memes, setMemes] = useState([]);
    const [isDeployOpen, setIsDeployOpen] = useState(false);
    const [refreshing, setRefreshing] = useState(false);

    const fetchMemes = async () => {
        if (!factoryContract) return;
        try {
            setRefreshing(true);
            const count = await factoryContract.getMemesCount();
            const memeList = [];
            for (let i = 0; i < Number(count); i++) {
                const addr = await factoryContract.allMemes(i);
                const info = await factoryContract.getMemeInfo(addr);
                memeList.push({
                    address: addr,
                    creator: info[0],
                    symbol: info[1],
                    totalSupply: info[2],
                    perMint: info[3],
                    price: info[4],
                    totalMinted: info[5],
                    remainingSupply: info[6]
                });
            }
            setMemes(memeList.reverse()); // Newest first
        } catch (err) {
            console.error("Fetch error:", err);
        } finally {
            setRefreshing(false);
        }
    };

    useEffect(() => {
        if (factoryContract) fetchMemes();
    }, [factoryContract]);

    return (
        <div className="min-h-screen p-4 md:p-8">
            {/* Navbar */}
            <nav className="max-w-7xl mx-auto flex justify-between items-center mb-12 glass-panel p-4 px-8">
                <div className="flex items-center gap-3">
                    <div className="p-2 bg-gradient-to-br from-indigo-500 to-pink-500 rounded-xl shadow-lg">
                        <Rocket className="text-white w-6 h-6" />
                    </div>
                    <span className="text-2xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-gray-400">
                        MemeFactory
                    </span>
                </div>

                <div className="flex items-center gap-4">
                    <AnimatePresence mode="wait">
                        {!account ? (
                            <motion.button
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                exit={{ opacity: 0, x: -20 }}
                                onClick={connectWallet}
                                className="btn-primary flex items-center gap-2"
                                disabled={loading}
                            >
                                <Wallet className="w-4 h-4" />
                                {loading ? "Connecting..." : "Connect Wallet"}
                            </motion.button>
                        ) : (
                            <motion.div
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                className="flex items-center gap-3 glass-card px-4 py-2"
                            >
                                <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
                                <span className="text-sm font-medium text-gray-300">
                                    {account.slice(0, 6)}...{account.slice(-4)}
                                </span>
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </nav>

            {/* Main Content */}
            <main className="max-w-7xl mx-auto">
                {/* Hero Section */}
                <section className="mb-16 grid grid-cols-1 lg:grid-cols-2 gap-8 items-center">
                    <motion.div
                        initial={{ opacity: 0, y: 30 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.8 }}
                    >
                        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 text-sm font-medium mb-6">
                            <TrendingUp className="w-4 h-4" />
                            <span>Next Gen Meme Infrastructure</span>
                        </div>
                        <h1 className="text-5xl md:text-7xl font-bold leading-tight mb-6">
                            Launch Your Vision <br />
                            in <span className="text-indigo-400">Pure Glass</span>.
                        </h1>
                        <p className="text-lg text-gray-400 mb-8 max-w-lg">
                            Deploy hyper-optimized ERC20 meme tokens using minimal proxy pattern.
                            Integrated liquidity, smart routing, and refined aesthetics.
                        </p>
                        <div className="flex gap-4">
                            <button
                                onClick={() => setIsDeployOpen(true)}
                                className="btn-primary flex items-center gap-2 px-8 py-4 text-lg"
                            >
                                <Plus className="w-5 h-5" />
                                Deploy Now
                            </button>
                            <button
                                onClick={fetchMemes}
                                className="glass-card flex items-center gap-2 px-8 py-4 text-lg"
                            >
                                <RefreshCw className={`w-5 h-5 ${refreshing ? 'animate-spin' : ''}`} />
                                Refresh
                            </button>
                        </div>
                    </motion.div>

                    <motion.div
                        initial={{ opacity: 0, scale: 0.9 }}
                        animate={{ opacity: 1, scale: 1 }}
                        transition={{ duration: 1 }}
                        className="hidden lg:block relative"
                    >
                        {/* Visual Flair */}
                        <div className="absolute -top-20 -right-20 w-64 h-64 bg-indigo-600/20 rounded-full blur-[100px]" />
                        <div className="absolute -bottom-20 -left-20 w-64 h-64 bg-pink-600/20 rounded-full blur-[100px]" />
                        <div className="glass-panel p-8 relative overflow-hidden">
                            <div className="flex justify-between items-start mb-8">
                                <div className="glass-card p-4 flex flex-col items-center gap-2">
                                    <PieChart className="text-indigo-400" />
                                    <span className="text-xs text-gray-400 uppercase tracking-widest">Fees</span>
                                    <span className="font-bold">5% / 95%</span>
                                </div>
                                <div className="glass-card p-4 flex flex-col items-center gap-2">
                                    <ShieldCheck className="text-green-400" />
                                    <span className="text-xs text-gray-400 uppercase tracking-widest">Security</span>
                                    <span className="font-bold">Verified</span>
                                </div>
                                <div className="glass-card p-4 flex flex-col items-center gap-2">
                                    <Coins className="text-yellow-400" />
                                    <span className="text-xs text-gray-400 uppercase tracking-widest">Supply</span>
                                    <span className="font-bold">Capped</span>
                                </div>
                            </div>
                            <div className="h-32 bg-indigo-500/5 rounded-2xl border border-indigo-500/10 flex items-center justify-center">
                                <span className="text-indigo-300 font-mono">0x...{FACTORY_ADDRESS.slice(-8)}</span>
                            </div>
                        </div>
                    </motion.div>
                </section>

                {/* Token Grid */}
                <section>
                    <div className="flex justify-between items-end mb-8">
                        <div>
                            <h2 className="text-3xl font-bold mb-2">Live Factory Output</h2>
                            <p className="text-gray-400">Tokens being minted and traded in real-time.</p>
                        </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 stagger-reveal">
                        {memes.length > 0 ? (
                            memes.map((meme, idx) => (
                                <TokenCard key={meme.address} meme={meme} factoryContract={factoryContract} provider={provider} />
                            ))
                        ) : (
                            <div className="col-span-full py-20 text-center glass-panel">
                                <Info className="w-12 h-12 text-gray-600 mx-auto mb-4" />
                                <p className="text-gray-500">No meme tokens found. Be the first to deploy!</p>
                            </div>
                        )}
                    </div>
                </section>
            </main>

            {/* Modals */}
            <AnimatePresence>
                {isDeployOpen && (
                    <DeployModal
                        onClose={() => setIsDeployOpen(false)}
                        onSuccess={fetchMemes}
                        factoryContract={factoryContract}
                    />
                )}
            </AnimatePresence>

            {error && (
                <div className="fixed bottom-8 right-8 glass-panel p-4 border-red-500/30 text-red-400 flex items-center gap-3">
                    <Info className="w-5 h-5" />
                    {error}
                </div>
            )}
        </div>
    );
}

export default App;
