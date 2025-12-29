import { useState } from 'react';
import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { parseEther } from 'viem';
import { FACTORY_ADDRESS, FACTORY_ABI } from '../contracts';

export function DeployInscription({ onDeployed }) {
    const { isConnected } = useAccount();
    const [symbol, setSymbol] = useState('');
    const [totalSupply, setTotalSupply] = useState('');
    const [perMint, setPerMint] = useState('');
    const [price, setPrice] = useState('');

    const { writeContract, data: hash, isPending, error, reset } = useWriteContract();

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    const handleSubmit = (e) => {
        e.preventDefault();

        const args = [
            symbol,
            parseEther(totalSupply),
            parseEther(perMint),
            parseEther(price || '0')
        ];

        writeContract({
            address: FACTORY_ADDRESS,
            abi: FACTORY_ABI,
            functionName: 'deployInscription',
            args,
        });
    };

    // Reset form and notify parent when deploy succeeds
    if (isSuccess && onDeployed) {
        setTimeout(() => {
            setSymbol('');
            setTotalSupply('');
            setPerMint('');
            setPrice('');
            reset();
            onDeployed();
        }, 1000);
    }

    return (
        <div className="card">
            <h2>🚀 部署铭文</h2>
            <form onSubmit={handleSubmit} className="deploy-form">
                <div className="form-group">
                    <label>符号 (Symbol)</label>
                    <input
                        type="text"
                        value={symbol}
                        onChange={(e) => setSymbol(e.target.value)}
                        placeholder="例如: MEME"
                        required
                    />
                </div>

                <div className="form-group">
                    <label>最大供应量 (Total Supply)</label>
                    <input
                        type="number"
                        value={totalSupply}
                        onChange={(e) => setTotalSupply(e.target.value)}
                        placeholder="例如: 21000000"
                        required
                        min="1"
                    />
                </div>

                <div className="form-group">
                    <label>每次铸造数量 (Per Mint)</label>
                    <input
                        type="number"
                        value={perMint}
                        onChange={(e) => setPerMint(e.target.value)}
                        placeholder="例如: 1000"
                        required
                        min="1"
                    />
                </div>

                <div className="form-group">
                    <label>铸造价格 (ETH) <span className="optional">可选</span></label>
                    <input
                        type="number"
                        step="0.0001"
                        value={price}
                        onChange={(e) => setPrice(e.target.value)}
                        placeholder="0 = 免费铸造"
                        min="0"
                    />
                </div>

                {error && (
                    <div className="error-message">
                        ❌ {error.shortMessage || '部署失败'}
                    </div>
                )}

                {isSuccess && (
                    <div className="success-message">
                        ✅ 铭文部署成功！
                    </div>
                )}

                <button
                    type="submit"
                    className="btn btn-primary"
                    disabled={!isConnected || isPending || isConfirming}
                >
                    {isPending ? '确认中...' : isConfirming ? '部署中...' : '部署铭文'}
                </button>
            </form>
        </div>
    );
}
