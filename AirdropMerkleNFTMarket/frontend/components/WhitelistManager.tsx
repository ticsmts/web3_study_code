'use client';

import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { isAddress } from 'viem';
import { CONTRACTS, MARKET_ABI } from '@/config/contracts';
import { buildMerkleTree, getMerkleProof, computeLeaf } from '@/utils/merkleTree';

/**
 * WhitelistManager Component
 * 管理员用于管理白名单和设置 Merkle Root
 */
export default function WhitelistManager() {
    const { address } = useAccount();
    const [whitelistInput, setWhitelistInput] = useState('');
    const [whitelistAddresses, setWhitelistAddresses] = useState<`0x${string}`[]>([]);
    const [merkleRoot, setMerkleRoot] = useState<`0x${string}` | null>(null);
    const [proofAddress, setProofAddress] = useState('');
    const [generatedProof, setGeneratedProof] = useState<`0x${string}`[] | null>(null);
    const [isWhitelisted, setIsWhitelisted] = useState<boolean | null>(null);

    // 读取市场 admin
    const { data: admin } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'admin',
    });

    // 读取当前 Merkle Root
    const { data: currentRoot, refetch: refetchRoot } = useReadContract({
        address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
        abi: MARKET_ABI,
        functionName: 'merkleRoot',
    });

    // setMerkleRoot 交易
    const {
        data: setRootHash,
        writeContract: setMerkleRootTx,
        isPending: isSetRootPending,
        error: setRootError,
    } = useWriteContract();

    const { isLoading: isSetRootConfirming, isSuccess: isSetRootSuccess, isError: isSetRootError } = useWaitForTransactionReceipt({
        hash: setRootHash,
    });

    const isAdmin = address && admin && address.toLowerCase() === (admin as string).toLowerCase();

    // 解析白名单地址
    const parseAddresses = (input: string): `0x${string}`[] => {
        const lines = input.split(/[\n,]/).map(line => line.trim()).filter(line => line);
        const validAddresses: `0x${string}`[] = [];
        for (const line of lines) {
            if (isAddress(line)) {
                validAddresses.push(line as `0x${string}`);
            }
        }
        return [...new Set(validAddresses)]; // 去重
    };

    // 当输入变化时解析地址并构建 Merkle 树
    useEffect(() => {
        const addresses = parseAddresses(whitelistInput);
        setWhitelistAddresses(addresses);

        if (addresses.length > 0) {
            const { root } = buildMerkleTree(addresses);
            setMerkleRoot(root);
        } else {
            setMerkleRoot(null);
        }
    }, [whitelistInput]);

    // 生成 Merkle Proof
    const handleGenerateProof = () => {
        if (!proofAddress || !isAddress(proofAddress) || whitelistAddresses.length === 0) {
            setGeneratedProof(null);
            setIsWhitelisted(false);
            return;
        }

        const proof = getMerkleProof(whitelistAddresses, proofAddress as `0x${string}`);
        setGeneratedProof(proof);

        // 检查是否在白名单中
        const leaf = computeLeaf(proofAddress as `0x${string}`);
        const { leaves } = buildMerkleTree(whitelistAddresses);
        setIsWhitelisted(leaves.includes(leaf));
    };

    // 设置 Merkle Root
    const handleSetMerkleRoot = async () => {
        if (!merkleRoot || !isAdmin) return;

        try {
            await setMerkleRootTx({
                address: CONTRACTS.MARKET_ADDRESS as `0x${string}`,
                abi: MARKET_ABI,
                functionName: 'setMerkleRoot',
                args: [merkleRoot],
            });
        } catch (error) {
            console.error('Set Merkle Root failed:', error);
        }
    };

    // 设置成功后刷新
    useEffect(() => {
        if (isSetRootSuccess) {
            refetchRoot();
        }
    }, [isSetRootSuccess, refetchRoot]);

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">🌳 白名单管理</h3>
                <span className={`badge ${isAdmin ? 'badge-success' : 'badge-warning'}`}>
                    {isAdmin ? 'Admin' : '仅限 Admin'}
                </span>
            </div>

            {/* 当前 Merkle Root */}
            <div className="mb-4 p-3 rounded-lg" style={{ background: 'rgba(99, 102, 241, 0.1)' }}>
                <div className="text-sm mb-1" style={{ color: 'var(--text-secondary)' }}>当前链上 Merkle Root:</div>
                <div className="font-mono text-xs break-all" style={{ color: 'var(--accent-primary)' }}>
                    {currentRoot ? (currentRoot as string) : '未设置'}
                </div>
            </div>

            <div className="space-y-4">
                {/* 白名单地址输入 */}
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        白名单地址列表（每行一个或逗号分隔）
                    </label>
                    <textarea
                        className="input-field font-mono text-xs"
                        placeholder="0x70997970C51812dc3A010C7d01b50e0d17dc79C8&#10;0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
                        value={whitelistInput}
                        onChange={(e) => setWhitelistInput(e.target.value)}
                        rows={5}
                    />
                    <div className="text-xs mt-1" style={{ color: 'var(--text-secondary)' }}>
                        已解析 {whitelistAddresses.length} 个有效地址
                    </div>
                </div>

                {/* 计算出的 Merkle Root */}
                {merkleRoot && (
                    <div className="p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)' }}>
                        <div className="text-sm mb-1" style={{ color: 'var(--success)' }}>计算得到的 Merkle Root:</div>
                        <div className="font-mono text-xs break-all">{merkleRoot}</div>
                    </div>
                )}

                {/* 设置 Merkle Root 按钮 */}
                <button
                    className="btn-primary w-full"
                    onClick={handleSetMerkleRoot}
                    disabled={!isAdmin || !merkleRoot || isSetRootPending || isSetRootConfirming}
                >
                    {isSetRootPending || isSetRootConfirming ? (
                        <span className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            设置中...
                        </span>
                    ) : (
                        '📝 设置 Merkle Root'
                    )}
                </button>

                {/* 状态提示 */}
                {isSetRootSuccess && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }}>
                        ✓ Merkle Root 设置成功!
                    </div>
                )}
                {(isSetRootError || setRootError) && (
                    <div className="text-sm p-3 rounded-lg" style={{ background: 'rgba(239, 68, 68, 0.1)', color: 'var(--error)' }}>
                        ✗ 设置失败: {setRootError?.message?.slice(0, 50) || '交易失败'}
                    </div>
                )}

                <hr className="border-t" style={{ borderColor: 'var(--border)' }} />

                {/* Merkle Proof 生成器 */}
                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        🔍 获取用户的 Merkle Proof
                    </label>
                    <div className="flex gap-2">
                        <input
                            type="text"
                            className="input-field flex-1 font-mono text-xs"
                            placeholder="输入用户地址..."
                            value={proofAddress}
                            onChange={(e) => setProofAddress(e.target.value)}
                        />
                        <button
                            className="btn-secondary"
                            onClick={handleGenerateProof}
                            disabled={!proofAddress || whitelistAddresses.length === 0}
                        >
                            生成
                        </button>
                    </div>
                </div>

                {/* 生成的 Proof */}
                {generatedProof !== null && (
                    <div className="p-3 rounded-lg" style={{
                        background: isWhitelisted ? 'rgba(16, 185, 129, 0.1)' : 'rgba(239, 68, 68, 0.1)'
                    }}>
                        <div className="text-sm mb-2">
                            {isWhitelisted ? (
                                <span style={{ color: 'var(--success)' }}>✓ 地址在白名单中</span>
                            ) : (
                                <span style={{ color: 'var(--error)' }}>✗ 地址不在白名单中</span>
                            )}
                        </div>
                        {isWhitelisted && (
                            <>
                                <div className="text-xs mb-1" style={{ color: 'var(--text-secondary)' }}>
                                    Merkle Proof (复制到购买组件中使用):
                                </div>
                                <div className="font-mono text-xs break-all p-2 rounded" style={{ background: 'rgba(0,0,0,0.2)' }}>
                                    {JSON.stringify(generatedProof)}
                                </div>
                            </>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
}
