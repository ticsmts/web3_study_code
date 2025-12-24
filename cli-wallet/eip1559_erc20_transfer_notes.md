# EIP-1559 ERC20 Transfer：从构造到签名（复习笔记）

> 目标：理解一笔 **EIP-1559（Type 2）** 的 **ERC20 `transfer`** 交易是如何从“人类意图”变成链上可传播的字节流，并掌握 `data` 字段与签名的原理。

---

## 1) 从“我要转 20000 个 ZZTOKEN”到交易对象

你在命令行输入：

- token 合约：`token`
- 收款地址：`to`
- 金额（人类单位）：`amountHuman`（比如 `20000`）

钱包要把它变成一笔 EVM 交易（交易不是 JSON，本质是结构化字段，最后会被序列化成字节）。

典型 EIP-1559 交易（type 2）你在 `tx.json` 里看到的字段，大概是：

- `chainId`：11155111（Sepolia）
- `nonce`：你的账户第几笔交易
- `to`：token 合约地址
- `value`：0
- `data`：函数调用编码（最关键）
- `gas`：gas 上限（estimate）
- `maxFeePerGas`、`maxPriorityFeePerGas`：EIP-1559 费用
- （可选）`accessList`：通常空
- `type`：eip1559（type 2）

**注意**：`from` 不会出现在最终链上传播的交易里，它是通过签名恢复出来的。

---

## 2) `data` 字段是什么：合约调用的“指令 + 参数”

对 ERC20 的 `transfer(address to, uint256 value)` 来说，`data` 由两部分组成：

### A. 函数选择器（4 bytes）

计算方法：

- `selector = keccak256("transfer(address,uint256)")` 的前 4 个字节

这 4 字节就是告诉 EVM：“我要调用哪个函数”。

（ERC20 transfer 的 selector 很常见，通常是 `0xa9059cbb`。）

### B. 参数编码（ABI encoding）

EVM 的 ABI 规则：每个参数占 32 字节（对静态类型来说）。

- `address`：20 字节地址，左侧补 0 填满 32 字节  
- `uint256`：大整数，按 32 字节 big-endian 表示，左侧补 0

因此：

```text
data = 0xa9059cbb
     + pad32(to)
     + pad32(amount)
```

### `amount` 怎么来的（decimals）

你输入的是人类单位 `amountHuman`，合约里存的是最小单位：

```text
amount = amountHuman * 10^decimals
```

例如 `decimals=18`，`20000` 会变成：

```text
20000 * 10^18 = 20000000000000000000000
```

钱包里 `parseUnits(amountHuman, decimals)` 做的就是这件事。

---

## 3) 一笔 EIP-1559 交易如何“被构造”出来（每个字段来源）

### `chainId`

- 固定：Sepolia = 11155111  
- 作用：防止跨链重放（签名会绑定 chainId）

### `nonce`

- 从 RPC 读：`getTransactionCount(address, "pending")`  
- 作用：保证交易顺序、避免重复；同 nonce 的交易只能最终上链一笔（另一笔要么被替换要么被丢弃）

### `to`

- ERC20 转账：`to = token 合约地址`（而不是收款人）

### `value`

- 一般是 0（你不需要给合约转 ETH）

### `data`

- 就是上面 ABI 编码出来的 calldata：`transfer(to, amount)` 的 selector + 参数

### `gas`

- 通过 `estimateGas({ from, to: token, data })` 估算  
- 注意：这是“上限”，实际扣费按 `gasUsed`（receipt 里）为准

### `maxPriorityFeePerGas / maxFeePerGas`

- 来自 `estimateFeesPerGas()` 或你自己策略设置  
- 真实生效：`min(maxFee, baseFee + priorityFee)`

---

## 4) 签名到底怎么签：你签的是“序列化后的交易哈希”

### 4.1 先把交易字段序列化（Type 2）

EIP-1559 交易（type 2）的“待签名消息”不是 JSON，而是：

```text
keccak256(
  0x02 || rlp([
    chainId,
    nonce,
    maxPriorityFeePerGas,
    maxFeePerGas,
    gas,
    to,
    value,
    data,
    accessList
  ])
)
```

关键点：

- 前面有一个 `0x02`（表示 type 2 交易）
- 然后对字段数组做 RLP 编码
- 再 keccak256 得到 32 字节 hash

### 4.2 用私钥对 hash 做 ECDSA 签名（secp256k1）

产生签名三元组：

- `r`
- `s`
- `yParity`（或叫 v 的变体，在 type 2 里是 yParity）

还会强制 `s` 在低半区（low-s）以防签名可塑性。

### 4.3 把签名塞回交易，得到最终 raw transaction

最终传播的是：

```text
0x02 || rlp([
  chainId,
  nonce,
  maxPriorityFeePerGas,
  maxFeePerGas,
  gas,
  to,
  value,
  data,
  accessList,
  yParity,
  r,
  s
])
```

这就是你 `rawtx.txt` 里的那串 `0x...`。

所以：你签名时如果任何字段变化（nonce/fee/to/data/chainId），签名就完全不同；这也是“钓鱼签名”危险的根源：你以为签 A，其实 UI 给你签了 B。

---

## 5) “from 地址”是怎么来的（为什么交易里没有 from）

节点收到 raw tx 后，会：

1. 取出签名 `(yParity, r, s)` 和消息 hash  
2. ECDSA 恢复出公钥  
3. 公钥再推导出地址：`from = keccak256(pubkey)[12:]`

恢复出的地址就是 `from`。

---

## 6) 你可以怎么“验证你签的是 transfer”（强烈建议做）

你已经会构造和发送了，下一步为了安全理解，建议你在发送前做两件事：

### 打印 selector

- 取 `data.slice(0, 10)`，应当是 `0xa9059cbb`

### 解码 data

- 用 viem 的 `decodeFunctionData({ abi, data })` 解出函数名和参数  
- 确认显示的是 `transfer`、收款地址、`amount`（最小单位/人类单位）

如果你想，可以在脚本里加一个 `inspect tx.json` 命令：读入 tx.json，把 data 解码成人类可读的“你将转给谁、转多少、gas 费用是多少”。
