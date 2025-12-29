import { useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { formatEther } from 'viem';
import { FACTORY_ADDRESS, FACTORY_ABI } from '../contracts';

export function MintButton({ tokenAddress, price = 0n, disabled, onMinted }) {
    const { isConnected } = useAccount();

    const { writeContract, data: hash, isPending, error, reset } = useWriteContract();

    const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
        hash,
    });

    const handleMint = () => {
        writeContract({
            address: FACTORY_ADDRESS,
            abi: FACTORY_ABI,
            functionName: 'mintInscription',
            args: [tokenAddress],
            value: price, // V2: 支付价格
        });
    };

    // Notify parent and reset when mint succeeds
    if (isSuccess && onMinted) {
        setTimeout(() => {
            onMinted();
            reset();
        }, 1000);
    }

    if (error) {
        let errorMsg = error.shortMessage || '铸造失败';
        if (errorMsg.includes('InsufficientPayment')) {
            errorMsg = '支付金额不足';
        } else if (errorMsg.includes('ExceedsMaxSupply')) {
            errorMsg = '已超过最大供应量';
        }

        return (
            <div className="mint-error">
                <span className="error-text">❌ {errorMsg}</span>
                <button onClick={reset} className="btn btn-small">重试</button>
            </div>
        );
    }

    if (isSuccess) {
        return (
            <div className="mint-success">
                ✅ 铸造成功！
            </div>
        );
    }

    // 显示价格的按钮文本
    const getButtonText = () => {
        if (isPending) return '确认中...';
        if (isConfirming) return '铸造中...';
        if (disabled) return '已售罄';
        if (price > 0n) return `铸造 (${formatEther(price)} ETH)`;
        return '免费铸造';
    };

    return (
        <button
            onClick={handleMint}
            className={`btn btn-mint ${price > 0n ? 'btn-paid' : ''}`}
            disabled={!isConnected || disabled || isPending || isConfirming}
        >
            {getButtonText()}
        </button>
    );
}
