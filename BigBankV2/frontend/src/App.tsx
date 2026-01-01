import { useAccount, useConnect, useDisconnect } from 'wagmi'
import DepositForm from './components/DepositForm'
import TopDepositors from './components/TopDepositors'
import UserBalance from './components/UserBalance'
import './App.css'

function WalletConnect() {
  const { connectors, connect, isPending } = useConnect()
  const { address, isConnected } = useAccount()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <div className="wallet-connected">
        <span className="wallet-address">
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </span>
        <button className="disconnect-button" onClick={() => disconnect()}>
          断开连接
        </button>
      </div>
    )
  }

  // 只使用第一个可用的连接器（避免重复按钮）
  const connector = connectors[0]
  if (!connector) return null

  return (
    <div className="wallet-buttons">
      <button
        className="connect-button"
        onClick={() => connect({ connector })}
        disabled={isPending}
      >
        {isPending ? '连接中...' : '连接 MetaMask'}
      </button>
    </div>
  )
}

function App() {
  const { isConnected } = useAccount()

  return (
    <div className="app">
      <header className="header">
        <div className="logo">
          <span className="logo-icon">🏦</span>
          <h1>BigBankV2</h1>
        </div>
        <WalletConnect />
      </header>

      <main className="main">
        <div className="hero">
          <h2>去中心化存款银行</h2>
          <p>安全存储您的 ETH，进入存款排行榜前 10 名</p>
        </div>

        {isConnected ? (
          <div className="dashboard">
            <div className="left-panel">
              <UserBalance />
              <DepositForm />
            </div>
            <div className="right-panel">
              <TopDepositors />
            </div>
          </div>
        ) : (
          <div className="connect-prompt">
            <div className="connect-card">
              <span className="connect-icon">🔗</span>
              <h3>连接钱包</h3>
              <p>连接您的钱包以开始存款</p>
              <WalletConnect />
            </div>
          </div>
        )}
      </main>

      <footer className="footer">
        <p>BigBankV2 · Powered by Ethereum</p>
      </footer>
    </div>
  )
}

export default App
