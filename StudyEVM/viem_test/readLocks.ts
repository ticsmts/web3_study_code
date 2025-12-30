// readLocks.ts
import {
  createPublicClient,
  http,
  keccak256,
  toHex,
  hexToBigInt,
  getAddress,
  formatEther,
  type Hex,
} from 'viem'
import { sepolia, mainnet, anvil } from 'viem/chains'

// 1) 配置 RPC & 合约地址
const RPC_URL = "http://127.0.0.1:8545/"
const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3" as Hex

const client = createPublicClient({
  chain: anvil, // 改成你部署的链：mainnet / holesky / anvil 等
  transport: http(RPC_URL),
})

// 把 bigint slot 转成 32-byte hex（EVM 需要 32 bytes slot key）
function slotToHex(slot: bigint): Hex {
  return toHex(slot, { size: 32 })
}

async function main() {
  // _locks 是第一个状态变量 => slot index = 0
  const LOCKS_SLOT = 0n

  // 2) 读取动态数组长度：storage[LOCKS_SLOT]
  const lengthHex = await client.getStorageAt({
    address: CONTRACT_ADDRESS,
    slot: slotToHex(LOCKS_SLOT),
  })

  const length = hexToBigInt(lengthHex)
  console.log(`_locks.length = ${length}`)

  // 3) 计算动态数组数据起点 base = keccak256(pad32(slot))
  const base = hexToBigInt(keccak256(slotToHex(LOCKS_SLOT)))

  // 每个 LockInfo 占 2 个 slot
  const STRIDE = 2n

  for (let i = 0n; i < length; i++) {
    const elementStart = base + i * STRIDE

    // 4) 读取 packed slot：user + startTime
    const packed = await client.getStorageAt({
      address: CONTRACT_ADDRESS,
      slot: slotToHex(elementStart),
    })

    // 5) 读取 amount slot
    const amountHex = await client.getStorageAt({
      address: CONTRACT_ADDRESS,
      slot: slotToHex(elementStart + 1n),
    })

    // packed 是 32 bytes： [padding4][startTime8][user20]
    const packedNo0x = packed.slice(2).padStart(64, '0')

    // user：最后 20 bytes = 40 hex chars
    const userHex = ('0x' + packedNo0x.slice(64 - 40)) as Hex
    const user = getAddress(userHex)

    // startTime：紧挨着 user 左边的 8 bytes = 16 hex chars
    const startTimeHex = ('0x' +
      packedNo0x.slice(64 - 40 - 16, 64 - 40)) as Hex
    const startTime = Number(BigInt(startTimeHex))

    // amount：uint256
    const amount = hexToBigInt(amountHex)

    console.log(
      `locks[${i}]: user:${user}, startTime:${startTime}, amount:${amount} (${formatEther(amount)} ether)`
    )
  }
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
