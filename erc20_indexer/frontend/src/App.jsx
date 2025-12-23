import { useState, useEffect, useCallback } from 'react'
import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from 'wagmi'
import { CHAINS, API_URL } from './config'

function App() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()

  const [transfers, setTransfers] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)
  const [stats, setStats] = useState({ total: 0 })

  const loadTransfers = useCallback(async () => {
    if (!address || !chainId) {
      console.log('⚠️ 跳过加载: address=', address, 'chainId=', chainId)
      return
    }

    const url = `${API_URL}/api/transfers/${address}?chainId=${chainId}&page=1&limit=50`
    console.log('🔍 开始请求API:', url)

    setLoading(true)
    setError(null)

    try {
      const response = await fetch(url)
      console.log('📡 API响应状态:', response.status, response.statusText)

      if (!response.ok) throw new Error(`API请求失败: ${response.status}`)

      const data = await response.json()
      console.log('✅ 收到数据:', data)
      console.log('📊 转账记录数:', data.data.length)

      setTransfers(data.data)
      setStats({ total: data.pagination.total })
    } catch (err) {
      console.error('❌ 加载失败:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [address, chainId])

  useEffect(() => {
    console.log('🔄 useEffect触发:', { isConnected, address, chainId })
    if (isConnected && address && chainId) {
      loadTransfers()
    }
  }, [isConnected, address, chainId, loadTransfers])

  // 切换到Anvil网络(如果不存在则先添加)
  const switchToAnvil = async () => {
    try {
      // 先尝试直接切换
      await switchChain({ chainId: 31337 })
    } catch (err) {
      console.log('直接切换失败，尝试添加网络...', err)
      // 如果切换失败，说明网络不存在，先添加
      try {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: '0x7a69', // 31337的十六进制
            chainName: 'Anvil Local',
            nativeCurrency: {
              name: 'Ethereum',
              symbol: 'ETH',
              decimals: 18,
            },
            rpcUrls: ['http://127.0.0.1:8545'],
          }],
        })
        console.log('✅ Anvil网络已添加')
        // 添加后会自动切换到该网络
      } catch (addErr) {
        console.error('添加网络失败:', addErr)
        alert('❌ 添加Anvil网络失败: ' + addErr.message)
      }
    }
  }

  const formatAmount = (value) => {
    const amount = BigInt(value)
    const decimals = 18
    const divisor = BigInt(10 ** decimals)
    const integerPart = amount / divisor
    const fractionalPart = amount % divisor

    if (fractionalPart === 0n) return integerPart.toString()

    const fractionalStr = fractionalPart.toString().padStart(decimals, '0')
    const trimmed = fractionalStr.replace(/0+$/, '')
    return `${integerPart}.${trimmed}`
  }

  const formatAddress = (addr) =>
    `${addr.substring(0, 6)}...${addr.substring(38)}`

  return (
    <div className="min-h-screen py-8 px-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="bg-white/95 backdrop-blur-sm rounded-3xl shadow-2xl p-8 mb-8">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h1 className="text-5xl font-bold bg-gradient-to-r from-primary-600 to-purple-600 bg-clip-text text-transparent mb-2">
                🔍 ERC20 Transfer Explorer
              </h1>
              <p className="text-gray-600 text-xl">实时查看你的代币转账记录</p>
            </div>
            <div className="flex items-center gap-3">
              {isConnected ? (
                <>
                  <div className="bg-gradient-to-r from-green-400 to-green-500 text-white px-6 py-3 rounded-xl font-semibold shadow-lg">
                    {formatAddress(address)}
                  </div>
                  <button
                    onClick={() => disconnect()}
                    className="bg-red-500 hover:bg-red-600 text-white px-6 py-3 rounded-xl font-semibold transition-all hover:scale-105 shadow-lg"
                  >
                    断开连接
                  </button>
                </>
              ) : (
                <button
                  onClick={() => connect({ connector: connectors[0] })}
                  className="bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700 text-white px-8 py-4 rounded-xl font-bold text-xl transition-all hover:scale-105 shadow-xl"
                >
                  🔌 连接 MetaMask
                </button>
              )}
            </div>
          </div>

          {isConnected && (
            <div className="flex items-center gap-4 pt-6 border-t border-gray-200">
              <span className="text-gray-700 font-semibold text-lg">🌐 选择网络:</span>
              <button
                onClick={switchToAnvil}
                className={`px-6 py-3 rounded-xl font-semibold transition-all ${chainId === 31337
                    ? 'bg-gradient-to-r from-primary-500 to-purple-600 text-white shadow-lg scale-105'
                    : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                  }`}
              >
                Anvil (本地) {chainId !== 31337 && '👈 点击添加'}
              </button>
              <button
                onClick={() => switchChain({ chainId: 11155111 })}
                className={`px-6 py-3 rounded-xl font-semibold transition-all ${chainId === 11155111
                    ? 'bg-gradient-to-r from-primary-500 to-purple-600 text-white shadow-lg scale-105'
                    : 'bg-gray-200 text-gray-700 hover:bg-gray-300'
                  }`}
              >
                Sepolia (测试网)
              </button>
            </div>
          )}
        </div>

        {/* Stats */}
        {isConnected && (
          <div className="bg-white/95 backdrop-blur-sm rounded-3xl shadow-2xl p-8 mb-8">
            <div className="grid grid-cols-3 gap-6">
              <div className="text-center">
                <div className="text-5xl font-bold bg-gradient-to-r from-blue-600 to-cyan-600 bg-clip-text text-transparent">
                  {stats.total}
                </div>
                <div className="text-gray-600 mt-2 font-medium">总转账数</div>
              </div>
              <div className="text-center">
                <div className="text-4xl font-bold bg-gradient-to-r from-green-600 to-emerald-600 bg-clip-text text-transparent">
                  {CHAINS[chainId]?.name || '未知'}
                </div>
                <div className="text-gray-600 mt-2 font-medium">当前网络</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold bg-gradient-to-r from-purple-600 to-pink-600 bg-clip-text text-transparent">
                  {CHAINS[chainId]?.tokenAddress ? formatAddress(CHAINS[chainId].tokenAddress) : '-'}
                </div>
                <div className="text-gray-600 mt-2 font-medium">代币地址</div>
              </div>
            </div>
            <button
              onClick={loadTransfers}
              disabled={loading}
              className="mt-6 w-full bg-gradient-to-r from-primary-500 to-purple-600 hover:from-primary-600 hover:to-purple-700 text-white px-6 py-4 rounded-xl font-bold text-lg transition-all hover:scale-105 shadow-lg disabled:opacity-50"
            >
              🔄 刷新数据
            </button>
          </div>
        )}

        {/* Transfers List */}
        <div className="bg-white/95 backdrop-blur-sm rounded-3xl shadow-2xl p-8">
          <h2 className="text-4xl font-bold text-gray-800 mb-6 flex items-center gap-3">
            <span className="text-5xl">📜</span>
            转账记录
          </h2>

          {!isConnected ? (
            <div className="text-center py-20">
              <div className="text-8xl mb-4">🔌</div>
              <p className="text-gray-600 text-2xl font-medium">请先连接钱包查看转账记录</p>
            </div>
          ) : loading ? (
            <div className="text-center py-20">
              <div className="animate-spin text-8xl mb-4">⏳</div>
              <p className="text-gray-600 text-2xl font-medium">加载中...</p>
            </div>
          ) : error ? (
            <div className="bg-red-50 border-2 border-red-200 rounded-2xl p-6 text-center">
              <div className="text-5xl mb-3">⚠️</div>
              <p className="text-red-600 font-semibold text-xl">加载失败: {error}</p>
              <p className="text-red-500 mt-2">请确保后端服务正在运行</p>
              <p className="text-sm text-gray-600 mt-2">请按F12打开开发者工具查看详细错误</p>
            </div>
          ) : transfers.length === 0 ? (
            <div className="text-center py-20">
              <div className="text-8xl mb-4">📭</div>
              <p className="text-gray-600 text-2xl font-medium">暂无转账记录</p>
              <p className="text-sm text-gray-500 mt-2">当前地址: {address}</p>
              <p className="text-sm text-gray-500">当前链ID: {chainId}</p>
            </div>
          ) : (
            <div className="space-y-4">
              {transfers.map((transfer) => (
                <div
                  key={`${transfer.tx_hash}-${transfer.log_index}`}
                  className="bg-gradient-to-r from-gray-50 to-blue-50 border-l-4 border-primary-500 rounded-2xl p-6 hover:shadow-xl transition-all hover:scale-[1.02]"
                >
                  <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                    <div>
                      <span className="text-gray-500 text-sm font-semibold">交易哈希</span>
                      <div className="text-gray-800 font-mono text-sm mt-1">
                        {formatAddress(transfer.tx_hash)}
                      </div>
                    </div>

                    <div>
                      <span className="text-gray-500 text-sm font-semibold">发送方</span>
                      <div className="text-gray-800 font-mono text-sm mt-1 flex items-center gap-2">
                        {formatAddress(transfer.from_address)}
                        {transfer.from_address.toLowerCase() === address?.toLowerCase() && (
                          <span className="bg-blue-500 text-white text-xs px-2 py-1 rounded-full font-bold">你</span>
                        )}
                      </div>
                    </div>

                    <div>
                      <span className="text-gray-500 text-sm font-semibold">接收方</span>
                      <div className="text-gray-800 font-mono text-sm mt-1 flex items-center gap-2">
                        {formatAddress(transfer.to_address)}
                        {transfer.to_address.toLowerCase() === address?.toLowerCase() && (
                          <span className="bg-green-500 text-white text-xs px-2 py-1 rounded-full font-bold">你</span>
                        )}
                      </div>
                    </div>

                    <div>
                      <span className="text-gray-500 text-sm font-semibold">金额</span>
                      <div className="text-3xl font-bold bg-gradient-to-r from-primary-600 to-purple-600 bg-clip-text text-transparent mt-1">
                        {formatAmount(transfer.value)} ZZ
                      </div>
                    </div>

                    <div>
                      <span className="text-gray-500 text-sm font-semibold">区块高度</span>
                      <div className="text-gray-800 font-mono mt-1">
                        #{transfer.block_number}
                      </div>
                    </div>

                    <div>
                      <span className="text-gray-500 text-sm font-semibold">时间</span>
                      <div className="text-gray-800 text-sm mt-1">
                        {new Date(transfer.timestamp * 1000).toLocaleString('zh-CN')}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="text-center mt-8 text-white/80 text-sm">
          <p>由 Vite + React + Wagmi + TailwindCSS 强力驱动 ⚡</p>
        </div>
      </div>
    </div>
  )
}

export default App
