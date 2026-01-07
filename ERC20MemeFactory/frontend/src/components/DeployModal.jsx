import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { X, Rocket, Coins, BarChart3, Tag } from 'lucide-react';
import { ethers } from 'ethers';

const DeployModal = ({ onClose, onSuccess, factoryContract }) => {
    const [formData, setFormData] = useState({
        symbol: '',
        totalSupply: '1000000',
        perMint: '1000',
        price: '0.001'
    });
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!factoryContract) return;

        try {
            setLoading(true);
            const { symbol, totalSupply, perMint, price } = formData;

            const tx = await factoryContract.deployMeme(
                symbol,
                ethers.parseEther(totalSupply),
                ethers.parseEther(perMint),
                ethers.parseEther(price)
            );

            await tx.wait();
            alert("Deployment successful!");
            onSuccess();
            onClose();
        } catch (err) {
            console.error(err);
            alert("Deployment failed: " + (err.reason || err.message));
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                onClick={onClose}
                className="absolute inset-0 bg-black/60 backdrop-blur-md"
            />

            <motion.div
                initial={{ scale: 0.9, opacity: 0, y: 20 }}
                animate={{ scale: 1, opacity: 1, y: 0 }}
                exit={{ scale: 0.9, opacity: 0, y: 20 }}
                className="glass-panel w-full max-w-lg p-8 relative z-10"
            >
                <button
                    onClick={onClose}
                    className="absolute top-6 right-6 p-2 hover:bg-white/5 rounded-full transition-colors"
                >
                    <X className="w-5 h-5" />
                </button>

                <div className="flex items-center gap-3 mb-8">
                    <div className="p-3 bg-indigo-500/20 rounded-2xl">
                        <Rocket className="text-indigo-400 w-6 h-6" />
                    </div>
                    <div>
                        <h2 className="text-2xl font-bold">Deploy Meme Token</h2>
                        <p className="text-sm text-gray-400">Mint your legacy on the blockchain.</p>
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    <div className="space-y-2">
                        <label className="text-sm font-medium text-gray-300 flex items-center gap-2">
                            <Tag className="w-4 h-4 text-indigo-400" /> Token Symbol
                        </label>
                        <input
                            type="text"
                            required
                            placeholder="e.g. PEPE"
                            className="w-full neu-input p-4 text-lg"
                            value={formData.symbol}
                            onChange={(e) => setFormData({ ...formData, symbol: e.target.value.toUpperCase() })}
                        />
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-gray-300 flex items-center gap-2">
                                <BarChart3 className="w-4 h-4 text-indigo-400" /> Total Supply
                            </label>
                            <input
                                type="number"
                                required
                                className="w-full neu-input"
                                value={formData.totalSupply}
                                onChange={(e) => setFormData({ ...formData, totalSupply: e.target.value })}
                            />
                        </div>
                        <div className="space-y-2">
                            <label className="text-sm font-medium text-gray-300 flex items-center gap-2">
                                <Coins className="w-4 h-4 text-indigo-400" /> Per Mint
                            </label>
                            <input
                                type="number"
                                required
                                className="w-full neu-input"
                                value={formData.perMint}
                                onChange={(e) => setFormData({ ...formData, perMint: e.target.value })}
                            />
                        </div>
                    </div>

                    <div className="space-y-2">
                        <label className="text-sm font-medium text-gray-300 flex items-center gap-2">
                            <Coins className="w-4 h-4 text-yellow-400" /> Price per Token (ETH)
                        </label>
                        <input
                            type="number"
                            step="0.000001"
                            required
                            className="w-full neu-input"
                            value={formData.price}
                            onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                        />
                        <p className="text-[10px] text-gray-500 p-1">
                            Example: 0.001 ETH per token = 1 ETH per 1000 tokens.
                        </p>
                    </div>

                    <div className="pt-4">
                        <button
                            type="submit"
                            disabled={loading || !factoryContract}
                            className="w-full btn-primary py-4 text-lg flex items-center justify-center gap-3"
                        >
                            {loading ? (
                                <>
                                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                    Deploying...
                                </>
                            ) : !factoryContract ? (
                                "Connect Wallet First"
                            ) : (
                                "Initialize Factory Protocol"
                            )}
                        </button>
                    </div>
                </form>
            </motion.div>
        </div>
    );
};

export default DeployModal;
