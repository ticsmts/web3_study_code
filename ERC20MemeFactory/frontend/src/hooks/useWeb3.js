import { useState, useEffect, useCallback } from 'react';
import { ethers } from 'ethers';
import MemeFactoryABI from '../abi/MemeFactory.json';
import MemeTokenABI from '../abi/MemeToken.json';
import { FACTORY_ADDRESS } from '../constants';

export function useWeb3() {
    const [provider, setProvider] = useState(null);
    const [signer, setSigner] = useState(null);
    const [account, setAccount] = useState(null);
    const [factoryContract, setFactoryContract] = useState(null);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);

    const connectWallet = useCallback(async () => {
        if (!window.ethereum) {
            setError("Please install MetaMask");
            return;
        }

        try {
            setLoading(true);
            const _provider = new ethers.BrowserProvider(window.ethereum);
            const _signer = await _provider.getSigner();
            const _account = await _signer.getAddress();

            const _factory = new ethers.Contract(FACTORY_ADDRESS, MemeFactoryABI.abi, _signer);

            setProvider(_provider);
            setSigner(_signer);
            setAccount(_account);
            setFactoryContract(_factory);
            setError(null);
        } catch (err) {
            console.error(err);
            setError("Failed to connect wallet");
        } finally {
            setLoading(false);
        }
    }, []);

    const getMemeTokenContract = (address) => {
        if (!signer) return null;
        return new ethers.Contract(address, MemeTokenABI.abi, signer);
    };

    useEffect(() => {
        if (window.ethereum) {
            window.ethereum.on('accountsChanged', (accounts) => {
                if (accounts.length > 0) connectWallet();
                else setAccount(null);
            });

            window.ethereum.on('chainChanged', () => {
                window.location.reload();
            });
        }
    }, [connectWallet]);

    return {
        provider,
        signer,
        account,
        factoryContract,
        loading,
        error,
        connectWallet,
        getMemeTokenContract
    };
}
