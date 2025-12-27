'use client';

import { useState } from 'react';
import { useAccount, usePublicClient } from 'wagmi';
import { parseEther, encodeFunctionData, createWalletClient, http, type Hex, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { CONTRACTS, TOKEN_ABI, BANK_ABI, DELEGATOR_ABI } from '@/config/contracts';

// Anvil chain definition with Prague hardfork
const anvilChain = {
    id: 31337,
    name: 'Anvil Local',
    nativeCurrency: { decimals: 18, name: 'Ether', symbol: 'ETH' },
    rpcUrls: { default: { http: ['http://127.0.0.1:8545'] } },
} as const;

// Anvil default test accounts
const ANVIL_ACCOUNTS = [
    {
        address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
    },
    {
        address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        privateKey: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',
    },
];

export default function V4EIP7702() {
    const { address, isConnected } = useAccount();
    const publicClient = usePublicClient();

    const [amount, setAmount] = useState('');
    const [status, setStatus] = useState<'idle' | 'signing' | 'sending' | 'confirming' | 'success' | 'error'>('idle');
    const [txHash, setTxHash] = useState<Hex | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [depositBefore, setDepositBefore] = useState<bigint | null>(null);
    const [depositAfter, setDepositAfter] = useState<bigint | null>(null);

    const getAnvilAccount = () => {
        if (!address) return null;
        return ANVIL_ACCOUNTS.find(
            acc => acc.address.toLowerCase() === address.toLowerCase()
        );
    };

    const handleBatchDeposit = async () => {
        if (!address || !amount || parseFloat(amount) <= 0 || !publicClient) {
            setError('请输入有效金额');
            return;
        }

        const anvilAccount = getAnvilAccount();
        if (!anvilAccount) {
            setError('请使用 Anvil 账户 #0 或 #1');
            return;
        }

        try {
            setStatus('signing');
            setError(null);
            setTxHash(null);
            setDepositAfter(null);

            const amountWei = parseEther(amount);

            // Get deposit before
            const beforeDeposit = await publicClient.readContract({
                address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                abi: BANK_ABI,
                functionName: 'depositedOf',
                args: [address],
            }) as bigint;
            setDepositBefore(beforeDeposit);

            console.log('[V4] Creating local account...');
            const account = privateKeyToAccount(anvilAccount.privateKey as `0x${string}`);

            const walletClient = createWalletClient({
                account,
                chain: anvilChain,
                transport: http(),
            });

            console.log('[V4] Signing EIP-7702 authorization...');
            console.log('[V4] Delegator address:', CONTRACTS.DELEGATOR_ADDRESS);

            // Get current nonce for the account
            const nonce = await publicClient.getTransactionCount({ address });
            console.log('[V4] Current account nonce:', nonce);

            // Sign EIP-7702 authorization with explicit nonce
            // For self-delegation: the authorization nonce should be the NEXT nonce
            // because the transaction that includes this authorization will use this nonce
            // CRITICAL: executor: 'self' is required when we sign AND send the transaction ourselves!
            const authorization = await walletClient.signAuthorization({
                contractAddress: CONTRACTS.DELEGATOR_ADDRESS as `0x${string}`,
                executor: 'self', // This is the key! Tells viem we're self-executing
            });
            console.log('[V4] Authorization signed:', authorization);
            console.log('[V4] Authorization nonce:', authorization.nonce);

            setStatus('sending');

            // Encode batch calls
            const approveData = encodeFunctionData({
                abi: TOKEN_ABI,
                functionName: 'approve',
                args: [CONTRACTS.BANK_ADDRESS as `0x${string}`, amountWei],
            });

            const depositData = encodeFunctionData({
                abi: BANK_ABI,
                functionName: 'deposit',
            });

            const batchCalls = [
                { target: CONTRACTS.TOKEN_ADDRESS as `0x${string}`, value: 0n, data: approveData },
                { target: CONTRACTS.BANK_ADDRESS as `0x${string}`, value: 0n, data: depositData },
            ];

            const executeData = encodeFunctionData({
                abi: DELEGATOR_ABI,
                functionName: 'execute',
                args: [batchCalls],
            });

            console.log('[V4] Sending type 0x04 transaction...');
            console.log('[V4] To (self):', address);
            console.log('[V4] Execute data:', executeData.slice(0, 66) + '...');

            // Send type 0x04 transaction
            const hash = await walletClient.sendTransaction({
                authorizationList: [authorization],
                to: address,
                data: executeData,
            });

            console.log('[V4] Transaction hash:', hash);
            setTxHash(hash);
            setStatus('confirming');

            // Wait for receipt
            const receipt = await publicClient.waitForTransactionReceipt({ hash });
            console.log('[V4] Transaction receipt:', receipt);

            if (receipt.status === 'reverted') {
                throw new Error('交易已回滚 (reverted)。请确保 Anvil 使用 --hardfork prague 启动');
            }

            // Verify deposit actually happened
            const afterDeposit = await publicClient.readContract({
                address: CONTRACTS.BANK_ADDRESS as `0x${string}`,
                abi: BANK_ABI,
                functionName: 'depositedOf',
                args: [address],
            }) as bigint;
            setDepositAfter(afterDeposit);

            console.log('[V4] Deposit before:', formatEther(beforeDeposit));
            console.log('[V4] Deposit after:', formatEther(afterDeposit));

            if (afterDeposit <= beforeDeposit) {
                throw new Error('存款未成功！请确保 Anvil 使用 --hardfork prague 启动，并重新部署合约');
            }

            setStatus('success');
        } catch (err: any) {
            console.error('[V4] Error:', err);

            let errorMsg = err.message || '交易失败';
            if (errorMsg.includes('signAuthorization')) {
                errorMsg = 'EIP-7702 授权签名失败';
            } else if (errorMsg.includes('hardfork') || errorMsg.includes('prague')) {
                errorMsg = '请使用 anvil --hardfork prague 启动';
            }

            setError(errorMsg.slice(0, 200));
            setStatus('error');
        }
    };

    const anvilAccount = getAnvilAccount();
    const isSupported = !!anvilAccount;

    const getStatusDisplay = () => {
        switch (status) {
            case 'signing': return { text: '签署授权中...', icon: '✍️' };
            case 'sending': return { text: '发送交易...', icon: '📤' };
            case 'confirming': return { text: '确认中...', icon: '⏳' };
            case 'success': return { text: '存款成功！', icon: '✅' };
            case 'error': return { text: '交易失败', icon: '❌' };
            default: return null;
        }
    };

    const statusDisplay = getStatusDisplay();

    return (
        <div className="card">
            <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-bold gradient-text">V4: EIP-7702 Batch</h3>
                <span className="badge badge-primary">1 Tx (Pectra)</span>
            </div>

            <p className="text-sm mb-4 leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
                使用 EIP-7702 让 EOA 临时变成智能合约，一笔交易原子完成 <strong>授权 + 存款</strong>。
            </p>

            <div className="space-y-4">
                {isConnected && !isSupported && (
                    <div className="p-3 rounded-lg border" style={{
                        background: 'rgba(239, 68, 68, 0.1)',
                        borderColor: 'rgba(239, 68, 68, 0.3)',
                        color: 'var(--error)'
                    }}>
                        <strong>⚠️ 不支持的账户</strong>
                        <div className="text-xs mt-1">请使用 Anvil 测试账户 #0 或 #1</div>
                    </div>
                )}

                <div className="p-3 rounded-lg border" style={{
                    background: 'rgba(99, 102, 241, 0.1)',
                    borderColor: 'rgba(99, 102, 241, 0.3)',
                }}>
                    <div className="text-sm" style={{ color: 'var(--accent-primary)' }}>
                        <strong>🚀 工作原理：</strong>
                        <ol className="mt-2 space-y-1 ml-4" style={{ color: 'var(--text-secondary)' }}>
                            <li>1. signAuthorization → EOA 临时获得代码</li>
                            <li>2. 交易 to = EOA，调用 execute()</li>
                            <li>3. 批量执行: approve → deposit</li>
                        </ol>
                    </div>
                </div>

                <div>
                    <label className="block text-sm font-medium mb-2" style={{ color: 'var(--text-secondary)' }}>
                        存款数量
                    </label>
                    <input
                        type="number"
                        className="input-field"
                        placeholder="0.0"
                        value={amount}
                        onChange={(e) => setAmount(e.target.value)}
                        disabled={status !== 'idle' && status !== 'success' && status !== 'error'}
                    />
                </div>

                <button
                    className="btn-primary w-full"
                    onClick={handleBatchDeposit}
                    disabled={!isConnected || !isSupported || !amount || status === 'signing' || status === 'sending' || status === 'confirming'}
                >
                    {status === 'idle' || status === 'success' || status === 'error' ? (
                        '⚡ EIP-7702 批量存款'
                    ) : (
                        <div className="flex items-center justify-center gap-2">
                            <div className="spinner"></div>
                            <span>{statusDisplay?.text}</span>
                        </div>
                    )}
                </button>

                {statusDisplay && status !== 'idle' && (
                    <div className="p-3 rounded-lg" style={{
                        background: status === 'success' ? 'rgba(16, 185, 129, 0.1)' :
                            status === 'error' ? 'rgba(239, 68, 68, 0.1)' :
                                'rgba(99, 102, 241, 0.1)',
                        color: status === 'success' ? 'var(--success)' :
                            status === 'error' ? 'var(--error)' :
                                'var(--accent-primary)'
                    }}>
                        <div className="flex items-center gap-2">
                            <span>{statusDisplay.icon}</span>
                            <span className="font-semibold">{statusDisplay.text}</span>
                        </div>
                        {txHash && (
                            <div className="text-xs mt-1 opacity-80">
                                Tx: {txHash.slice(0, 10)}...{txHash.slice(-8)}
                            </div>
                        )}
                        {status === 'success' && depositBefore !== null && depositAfter !== null && (
                            <div className="text-xs mt-2">
                                存款前: {formatEther(depositBefore)} ZZ → 存款后: {formatEther(depositAfter)} ZZ
                            </div>
                        )}
                    </div>
                )}

                {error && status === 'error' && (
                    <div className="text-sm p-3 rounded-lg" style={{
                        background: 'rgba(239, 68, 68, 0.1)',
                        color: 'var(--error)'
                    }}>
                        {error}
                    </div>
                )}

                <div className="text-xs p-3 rounded-lg" style={{
                    background: 'rgba(251, 146, 60, 0.1)',
                    color: '#fb923c'
                }}>
                    <strong>⚠️ 重要：</strong> Anvil 必须使用 <code>anvil --hardfork prague</code> 启动！
                </div>
            </div>
        </div>
    );
}
