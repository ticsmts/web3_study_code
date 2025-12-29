import { useState, useCallback } from 'react';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { config } from './wagmi';
import { WalletConnect, DeployInscription, InscriptionList, OwnerPanel } from './components';
import { FACTORY_VERSION, FACTORY_ADDRESS } from './contracts';
import './App.css';

const queryClient = new QueryClient();

function AppContent() {
  const [refreshTrigger, setRefreshTrigger] = useState(0);
  const [inscriptions, setInscriptions] = useState([]);

  const handleDeployed = useCallback(() => {
    setRefreshTrigger(prev => prev + 1);
  }, []);

  const handleInscriptionsLoaded = useCallback((data) => {
    setInscriptions(data);
  }, []);

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          <div className="logo">
            <span className="logo-icon">📜</span>
            <h1>Inscription Factory</h1>
            <span className="version-badge">{FACTORY_VERSION}</span>
          </div>
          <WalletConnect />
        </div>
      </header>

      <main className="main">
        <div className="container">
          <div className="contract-info">
            <span>合约地址: </span>
            <a
              href={`https://sepolia.etherscan.io/address/${FACTORY_ADDRESS}`}
              target="_blank"
              rel="noopener noreferrer"
            >
              {FACTORY_ADDRESS.slice(0, 10)}...{FACTORY_ADDRESS.slice(-8)}
            </a>
            <span className="network-badge">Sepolia</span>
          </div>

          <div className="grid-v2">
            <div className="sidebar">
              <DeployInscription onDeployed={handleDeployed} />
              <OwnerPanel inscriptions={inscriptions} />
            </div>
            <InscriptionList
              refreshTrigger={refreshTrigger}
              onInscriptionsLoaded={handleInscriptionsLoaded}
            />
          </div>
        </div>
      </main>

      <footer className="footer">
        <p>Inscription Factory {FACTORY_VERSION} - 可升级铭文工厂合约</p>
      </footer>
    </div>
  );
}

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <AppContent />
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
