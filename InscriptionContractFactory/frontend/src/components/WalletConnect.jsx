import { useConnect, useAccount, useDisconnect } from 'wagmi';

export function WalletConnect() {
    const { connectors, connect, isPending } = useConnect();
    const { address, isConnected, chain } = useAccount();
    const { disconnect } = useDisconnect();

    if (isConnected) {
        return (
            <div className="wallet-connected">
                <div className="wallet-info">
                    <span className="wallet-address">
                        {address?.slice(0, 6)}...{address?.slice(-4)}
                    </span>
                    <span className="wallet-network">
                        {chain?.name || 'Unknown'}
                    </span>
                </div>
                <button onClick={() => disconnect()} className="btn btn-disconnect">
                    断开连接
                </button>
            </div>
        );
    }

    return (
        <div className="wallet-connect">
            {connectors.map((connector) => (
                <button
                    key={connector.uid}
                    onClick={() => connect({ connector })}
                    disabled={isPending}
                    className="btn btn-connect"
                >
                    {isPending ? '连接中...' : `连接 ${connector.name}`}
                </button>
            ))}
        </div>
    );
}
