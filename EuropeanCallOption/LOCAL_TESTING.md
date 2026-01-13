# 本地节点手动测试指南

本指南演示如何在 Anvil 本地节点上手动测试期权合约的完整生命周期。

## 测试环境准备

### 1. 启动 Anvil 本地节点

打开一个终端窗口，启动 Anvil：

```bash
anvil
```

Anvil 启动后会显示 10 个测试账户和私钥：

```
Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000 ETH)
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
...
```

**账户分配：**
- Account #0 = Issuer（项目方）
- Account #1 = Alice（用户）

---

## 部署合约

在另一个终端运行部署脚本：

```bash
cd EuropeanCallOption
forge script script/DeployOption.s.sol --rpc-url http://localhost:8545 --broadcast
```

记下输出的合约地址，例如：
```
MockUSDT: 0x5FbDB2315678afecb367f032d93F642f64180aa3
OptionToken: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

---

## 手动测试步骤

### 设置环境变量

```bash
# 合约地址（根据部署输出修改）
$USDT = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
$OPTION = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"

# 账户地址
$ISSUER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
$ALICE = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

# 私钥
$ISSUER_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
$ALICE_KEY = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"

$RPC = "http://localhost:8545"
```

---

### Step 1: 查看初始状态

```bash
# 查看期权合约 ETH 余额
cast balance $OPTION --rpc-url $RPC

# 查看 Issuer 的 oETHC 余额
cast call $OPTION "balanceOf(address)(uint256)" $ISSUER --rpc-url $RPC

# 查看期权总供应量
cast call $OPTION "totalSupply()(uint256)" --rpc-url $RPC

# 查看行权价
cast call $OPTION "strikePrice()(uint256)" --rpc-url $RPC

# 查看到期时间
cast call $OPTION "expiry()(uint256)" --rpc-url $RPC
```

---

### Step 2: Issuer 转移期权给 Alice

```bash
# Issuer 转 2 oETHC 给 Alice (2 ether = 2e18 wei)
cast send $OPTION "transfer(address,uint256)" $ALICE 2000000000000000000 \
    --private-key $ISSUER_KEY \
    --rpc-url $RPC

# 验证 Alice 余额
cast call $OPTION "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC
# 应该显示: 2000000000000000000 (2 oETHC)

# 验证 Issuer 余额
cast call $OPTION "balanceOf(address)(uint256)" $ISSUER --rpc-url $RPC
# 应该显示: 8000000000000000000 (8 oETHC)
```

---

### Step 3: 给 Alice 铸造 USDT

```bash
# Alice 需要 USDT 来行权
# 2 ETH * 2000 USDT/ETH = 4000 USDT = 4000e6 = 4000000000

cast send $USDT "mint(address,uint256)" $ALICE 4000000000 \
    --private-key $ISSUER_KEY \
    --rpc-url $RPC

# 验证 Alice USDT 余额
cast call $USDT "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC
# 应该显示: 4000000000 (4000 USDT)
```

---

### Step 4: Alice 授权期权合约使用 USDT

```bash
# Alice 授权期权合约使用她的 USDT
cast send $USDT "approve(address,uint256)" $OPTION 4000000000 \
    --private-key $ALICE_KEY \
    --rpc-url $RPC

# 验证授权额度
cast call $USDT "allowance(address,address)(uint256)" $ALICE $OPTION --rpc-url $RPC
# 应该显示: 4000000000
```

---

### Step 5: 快进时间到行权窗口

```bash
# 查看当前区块时间戳
cast block latest --field timestamp --rpc-url $RPC

# 查看到期时间
cast call $OPTION "expiry()(uint256)" --rpc-url $RPC

# 快进时间到到期时间（增加 3601 秒 = 1小时1秒）
cast rpc evm_increaseTime 3601 --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC

# 验证是否在行权窗口
cast call $OPTION "isInExerciseWindow()(bool)" --rpc-url $RPC
# 应该显示: true
```

---

### Step 6: Alice 行权

```bash
# 记录行权前 Alice 的 ETH 余额
cast balance $ALICE --rpc-url $RPC

# Alice 行权 1 oETHC (1e18 wei)
# 需要支付: 1 * 2000 = 2000 USDT = 2000e6 = 2000000000
cast send $OPTION "exercise(uint256)" 1000000000000000000 \
    --private-key $ALICE_KEY \
    --rpc-url $RPC

# 验证行权后状态
echo "=== After Exercise ==="

# Alice oETHC 余额 (应该是 1 oETHC)
cast call $OPTION "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC

# Alice USDT 余额 (应该是 2000 USDT)
cast call $USDT "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC

# Issuer USDT 余额 (应该是 2000 USDT)
cast call $USDT "balanceOf(address)(uint256)" $ISSUER --rpc-url $RPC

# 合约 ETH 余额 (应该是 9 ETH)
cast balance $OPTION --rpc-url $RPC

# Alice ETH 余额应该增加约 1 ETH（扣除 gas）
cast balance $ALICE --rpc-url $RPC
```

---

### Step 7: 快进到窗口结束，Issuer 赎回

```bash
# 快进 24 小时
cast rpc evm_increaseTime 86400 --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC

# 验证期权已过期
cast call $OPTION "isExpired()(bool)" --rpc-url $RPC
# 应该显示: true

# 记录赎回前 Issuer ETH 余额
cast balance $ISSUER --rpc-url $RPC

# Issuer 赎回剩余 ETH
cast send $OPTION "reclaimExpired()" \
    --private-key $ISSUER_KEY \
    --rpc-url $RPC

# 验证赎回后状态
echo "=== After Reclaim ==="

# 合约 ETH 应该为 0
cast balance $OPTION --rpc-url $RPC

# Issuer ETH 应该增加 9 ETH（剩余未行权的）
cast balance $ISSUER --rpc-url $RPC
```

---

## 预期结果总结

| 阶段 | 合约 ETH | Issuer oETHC | Alice oETHC | Issuer USDT | Alice USDT |
|------|----------|--------------|-------------|-------------|------------|
| 部署后 | 10 | 10 | 0 | 0 | 0 |
| 转移后 | 10 | 8 | 2 | 0 | 4000 |
| 行权后 | 9 | 8 | 1 | 2000 | 2000 |
| 赎回后 | 0 | 8 | 1 (废弃) | 2000 | 2000 |

---

## 错误测试

### 测试 1: 到期前无法行权

```bash
# 重新部署合约后，不跳过时间直接行权
cast send $OPTION "exercise(uint256)" 1000000000000000000 \
    --private-key $ALICE_KEY \
    --rpc-url $RPC
# 预期: 交易失败，显示 NotInExerciseWindow()
```

### 测试 2: 非 Issuer 无法赎回

```bash
# Alice 尝试赎回
cast send $OPTION "reclaimExpired()" \
    --private-key $ALICE_KEY \
    --rpc-url $RPC
# 预期: 交易失败，显示 NotIssuer()
```

### 测试 3: 窗口内无法赎回

```bash
# 在行权窗口内尝试赎回
cast send $OPTION "reclaimExpired()" \
    --private-key $ISSUER_KEY \
    --rpc-url $RPC
# 预期: 交易失败，显示 NotExpired()
```

---

## Bash 脚本版本（Linux/Mac）

如果你在 Linux/Mac 上，可以使用这个脚本：

```bash
#!/bin/bash

# 合约地址
USDT="0x5FbDB2315678afecb367f032d93F642f64180aa3"
OPTION="0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"

# 账户
ISSUER="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
ALICE="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
ISSUER_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ALICE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
RPC="http://localhost:8545"

# ... 使用相同的 cast 命令
```

---

## 常用查询命令

```bash
# 查看期权参数
cast call $OPTION "name()(string)" --rpc-url $RPC
cast call $OPTION "symbol()(string)" --rpc-url $RPC
cast call $OPTION "decimals()(uint8)" --rpc-url $RPC
cast call $OPTION "strikePrice()(uint256)" --rpc-url $RPC
cast call $OPTION "expiry()(uint256)" --rpc-url $RPC
cast call $OPTION "issuer()(address)" --rpc-url $RPC

# 计算行权成本
cast call $OPTION "calculateUsdtPayment(uint256)(uint256)" 1000000000000000000 --rpc-url $RPC
# 1 ETH 需要 2000000000 (2000 USDT)
```
