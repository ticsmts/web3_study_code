# 全抵押欧式看涨期权 Token (European Call Option)

一个用于学习期权生命周期、资金流、单位换算和权限/时间限制的 Solidity 项目。

## 项目概述

本项目实现了一个**全抵押（Fully-Collateralized）欧式看涨期权（European Call）**Token，使用 ERC20 作为期权凭证。

### 核心特点

- **ERC20 期权凭证**：期权以 `oETHC` Token 形式存在，可自由转让
- **全额抵押**：项目方存入 ETH 作为抵押，1:1 铸造期权 Token
- **欧式期权**：只能在到期日当天（24h 窗口）行权
- **USDT 结算**：按固定行权价支付 USDT 获得 ETH

## 行权计算详解

### 核心公式

```
usdtToPay = amountWei * strikePrice / 1e18
```

### 具体数字示例

假设：
- `strikePrice = 2000e6` （2000 USDT/ETH，USDT 有 6 位小数）
- `amountWei = 0.4 ether` （用户要行权 0.4 个期权 Token）

计算过程：

```
amountWei = 0.4 ether = 0.4 * 10^18 = 4 * 10^17 wei

usdtToPay = amountWei * strikePrice / 1e18
         = (4 * 10^17) * (2000 * 10^6) / 10^18
         = (4 * 2000 * 10^23) / 10^18
         = 8 * 10^8 / 10^0
         = 800 * 10^6
         = 800e6 (USDT 最小单位)
         = 800 USDT
```

### 为什么要除以 1e18？

| Token | Decimals | 最小单位 |
|-------|----------|----------|
| ETH / oETHC | 18 | wei |
| USDT | 6 | 10^-6 USDT |

- `amountWei` 是以 **wei** 为单位（10^18 wei = 1 ETH）
- `strikePrice` 是 **每 1 ETH 需要支付多少 USDT 最小单位**
- 除以 `1e18` 将 wei 转换为 ETH 数量，再乘以 strikePrice 得到 USDT 最小单位

换句话说：
```
ETH数量 = amountWei / 1e18
USDT数量 = ETH数量 * strikePrice
        = (amountWei / 1e18) * strikePrice
        = amountWei * strikePrice / 1e18
```

## 期权生命周期

```
[部署] → [Issue 抵押] → [交易期权] → [行权窗口] → [过期赎回]
                                      ↓
                              可行权 24h 窗口
```

### 时间线

```
|-------- 发行期 --------|-- 行权窗口 --|---- 过期 ----|
                        expiry      expiry+1day
                          ↑             ↑
                    窗口开始        窗口结束
```

---

## 资金流测试详解

运行命令：
```bash
forge test --match-test FundFlow -vvv
```

### 测试 1: Issue（存入）资金流

**测试函数**: `test_FundFlow_Issue_Deposit()`

**资金流向**:
```
[Issuer] ---(5 ETH)---> [OptionToken Contract]
[Contract] ---(5 oETHC)---> [Issuer]
```

**测试输出**:
```
========== FUND FLOW: ISSUE (DEPOSIT) ==========
--- Before Issue ---
Issuer ETH balance: 100 ETH
Contract ETH balance: 0 ETH
Issuer oETHC balance: 0 oETHC
Total supply: 0 oETHC

--- After Issue (deposited 5 ETH) ---
Issuer ETH balance: 95 ETH (-5)      ← Issuer 支出 5 ETH
Contract ETH balance: 5 ETH (+5)     ← 合约收到 5 ETH 抵押
Issuer oETHC balance: 5 oETHC (+5)   ← Issuer 获得 5 oETHC
Total supply: 5 oETHC (+5)           ← 总供应量增加

--- Fund Flow Verification ---
All fund flow assertions passed!
```

**说明**: Issuer 存入 5 ETH，合约 1:1 铸造 5 oETHC 给 Issuer。这是全额抵押的核心机制。

---

### 测试 2: Exercise（行权）资金流

**测试函数**: `test_FundFlow_Exercise_Complete()`

**资金流向**:
```
[Alice] ---(3000 USDT)---> [Issuer]     (支付行权价)
[Alice] ---(1.5 oETHC)---> [Burn/销毁]   (销毁期权Token)
[Contract] ---(1.5 ETH)---> [Alice]     (获得标的资产)
```

**测试输出**:
```
========== FUND FLOW: EXERCISE ==========
--- Before Exercise ---
Alice ETH: 10 ETH
Alice USDT: 3000 USDT
Alice oETHC: 1 oETHC
Owner USDT: 0 USDT
Contract ETH: 2 ETH
Total supply: 2 oETHC

--- Executing Exercise: 1.5 oETHC ---
USDT to pay: (1.5 * 2000e6) / 1e18 = 3000 USDT

--- After Exercise ---
Alice ETH: 11 ETH (+1.5)             ← Alice 收到 1.5 ETH
Alice USDT: 0 USDT (-3000)           ← Alice 支付 3000 USDT
Alice oETHC: 0 oETHC (-1.5, burned)  ← Alice 的期权被销毁
Owner USDT: 3000 USDT (+3000)        ← Issuer 收到 3000 USDT
Contract ETH: 0 ETH (-1.5)           ← 合约释放 1.5 ETH
Total supply: 0 oETHC (-1.5)         ← 总供应量减少

--- Fund Flow Verification ---
All fund flow assertions passed!
```

**说明**: 行权时发生三方资金转移：
1. Alice 的 oETHC 被销毁
2. Alice 支付 USDT 给 Issuer
3. 合约释放抵押的 ETH 给 Alice

---

### 测试 3: Reclaim（赎回）资金流

**测试函数**: `test_FundFlow_Reclaim_Expired()`

**资金流向**:
```
[Contract] ---(remaining ETH)---> [Issuer]
```

**测试输出**:
```
========== FUND FLOW: RECLAIM EXPIRED ==========
--- After Alice exercised 1 ETH ---
Contract remaining ETH: 2 ETH        ← 原本 3 ETH，Alice 行权了 1 ETH
Remaining total supply: 2 oETHC     ← 未行权的期权

--- Before Reclaim (window expired) ---
Owner ETH: 97 ETH
Contract ETH (to reclaim): 2 ETH    ← 待赎回的抵押

--- Executing Reclaim ---

--- After Reclaim ---
Owner ETH: 99 ETH (+2)               ← Issuer 取回 2 ETH
Contract ETH: 0 ETH (empty)          ← 合约清空

--- Fund Flow Verification ---
Expected reclaim: 3 - 1 = 2 ETH
All fund flow assertions passed!
```

**说明**: 到期窗口结束后，未被行权的期权作废，Issuer 可以取回剩余的抵押 ETH。

---

### 测试 4: 完整生命周期

**测试函数**: `test_FundFlow_FullLifecycle()`

**测试输出**:
```
========== FUND FLOW: FULL LIFECYCLE ==========

[Phase 1] ISSUE - Issuer deposits 10 ETH
-------------------------------------------
Contract ETH: 10 ETH
Total oETHC: 10
Issuer oETHC: 10

[Phase 2] DISTRIBUTE - Transfer options to users
------------------------------------------------
Alice oETHC: 4                       ← Alice 获得 4 份期权
Bob oETHC: 3                         ← Bob 获得 3 份期权
Owner oETHC: 3                       ← Issuer 保留 3 份

[Phase 3] EXERCISE WINDOW
--------------------------
Alice exercised 2 oETHC:
  - Paid: 4000 USDT                  ← 2 ETH × 2000 USDT
  - Received: 2 ETH
  - Remaining oETHC: 2               ← Alice 还剩 2 份未行权

Bob exercised 3 oETHC:
  - Paid: 6000 USDT                  ← 3 ETH × 2000 USDT
  - Received: 3 ETH
  - Remaining oETHC: 0               ← Bob 全部行权

[Phase 4] EXPIRED - Reclaim remaining ETH
-----------------------------------------
Contract ETH before reclaim: 5 ETH   ← 10 - 5(已行权) = 5
Unexercised options:
  - Alice: 2 oETHC (expired worthless) ← 未行权，作废
  - Owner: 3 oETHC (expired worthless) ← 未行权，作废

After reclaim:
  - Owner received: 5 ETH            ← 取回未被行权的抵押
  - Contract ETH: 0 ETH

[SUMMARY]
=========
Total deposited: 10 ETH
Total exercised: 5 ETH (Alice 2 + Bob 3)
Total reclaimed: 5 ETH
Issuer USDT received: 10000 USDT     ← 5 ETH × 2000 USDT
```

**说明**: 展示了期权从发行到到期的完整生命周期：
- **发行**: 10 ETH 抵押，铸造 10 oETHC
- **分发**: 期权分配给用户
- **行权**: Alice 行权 2 份，Bob 行权 3 份
- **赎回**: 剩余 5 ETH 被 Issuer 取回

---

### 测试 5: 单位换算验证

**测试函数**: `test_FundFlow_UnitConversion()`

**测试输出**:
```
========== FUND FLOW: UNIT CONVERSION ==========
Strike Price: 2000 USDT/ETH

Amount: 1 ETH -> USDT: 2000          ← 1 × 2000 = 2000
Amount: 0.5 ETH -> USDT: 1000        ← 0.5 × 2000 = 1000
Amount: 0.001 ETH -> USDT: 2         ← 0.001 × 2000 = 2
Amount: 0.1 ETH -> USDT: 200         ← 0.1 × 2000 = 200
Amount: 2.5 ETH -> USDT: 5000        ← 2.5 × 2000 = 5000

Formula: usdtToPay = amountWei * strikePrice / 1e18

Example: 0.4 ETH
  amountWei = 0.4 * 1e18 = 4e17
  strikePrice = 2000 * 1e6 = 2e9
  usdtToPay = 4e17 * 2e9 / 1e18 = 8e8 = 800e6 = 800 USDT
```

**说明**: 验证不同金额的 ETH/USDT 换算，确保公式正确处理 decimals 差异。

---

## 本地节点手动测试

### 1. 启动 Anvil

打开终端，启动本地节点：

```bash
anvil
```

记下测试账户：
```
Account #0 (Issuer): 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account #1 (Alice): 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
```

### 2. 部署合约

```bash
forge script script/DeployOption.s.sol --rpc-url http://localhost:8545 --broadcast
```

记下输出的合约地址：
```
MockUSDT: 0x5FbDB2315678afecb367f032d93F642f64180aa3
OptionToken: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

### 3. 设置环境变量 (PowerShell)

```powershell
$USDT = "0x5FbDB2315678afecb367f032d93F642f64180aa3"
$OPTION = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"
$ISSUER = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
$ALICE = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
$ISSUER_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
$ALICE_KEY = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
$RPC = "http://localhost:8545"
```

### 4. 查看初始状态

```powershell
# 查看期权合约 ETH 余额 (应该是 10 ETH)
cast balance $OPTION --rpc-url $RPC

# 查看 Issuer 的 oETHC 余额
cast call $OPTION "balanceOf(address)(uint256)" $ISSUER --rpc-url $RPC

# 查看行权价
cast call $OPTION "strikePrice()(uint256)" --rpc-url $RPC
```

### 5. Issuer 转移期权给 Alice

```powershell
# 转 2 oETHC 给 Alice (2 ether = 2e18 wei)
cast send $OPTION "transfer(address,uint256)" $ALICE 2000000000000000000 `
    --private-key $ISSUER_KEY --rpc-url $RPC

# 验证 Alice 余额
cast call $OPTION "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC
```

### 6. 给 Alice 铸造 USDT

```powershell
# 2 ETH * 2000 USDT/ETH = 4000 USDT = 4000e6
cast send $USDT "mint(address,uint256)" $ALICE 4000000000 `
    --private-key $ISSUER_KEY --rpc-url $RPC

# 验证余额
cast call $USDT "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC
```

### 7. Alice 授权期权合约

```powershell
cast send $USDT "approve(address,uint256)" $OPTION 4000000000 `
    --private-key $ALICE_KEY --rpc-url $RPC
```

### 8. 快进时间到行权窗口

```powershell
# 查看到期时间
cast call $OPTION "expiry()(uint256)" --rpc-url $RPC

# 快进 1 小时 1 秒
cast rpc evm_increaseTime 3601 --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC

# 验证是否在行权窗口
cast call $OPTION "isInExerciseWindow()(bool)" --rpc-url $RPC
# 应该显示: true
```

### 9. Alice 行权

```powershell
# 行权 1 oETHC (需支付 2000 USDT)
cast send $OPTION "exercise(uint256)" 1000000000000000000 `
    --private-key $ALICE_KEY --rpc-url $RPC

# 验证结果
cast call $OPTION "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC  # 剩余 1 oETHC
cast call $USDT "balanceOf(address)(uint256)" $ALICE --rpc-url $RPC    # 剩余 2000 USDT
cast call $USDT "balanceOf(address)(uint256)" $ISSUER --rpc-url $RPC   # 收到 2000 USDT
```

### 10. 快进到窗口结束，Issuer 赎回

```powershell
# 快进 24 小时
cast rpc evm_increaseTime 86400 --rpc-url $RPC
cast rpc evm_mine --rpc-url $RPC

# 验证已过期
cast call $OPTION "isExpired()(bool)" --rpc-url $RPC
# 应该显示: true

# Issuer 赎回
cast send $OPTION "reclaimExpired()" --private-key $ISSUER_KEY --rpc-url $RPC

# 验证合约已清空
cast balance $OPTION --rpc-url $RPC
# 应该显示: 0
```

---

## 合约接口

### OptionToken.sol

```solidity
// 期权参数（部署时固定）
address public immutable settlementToken;  // USDT 地址
uint256 public immutable strikePrice;      // 行权价 (USDT/ETH)
uint256 public immutable expiry;           // 到期时间戳
address public immutable issuer;           // 项目方

// 核心函数
function issue() external payable;                    // 项目方抵押 ETH
function exercise(uint256 amountWei) external;        // 用户行权
function reclaimExpired() external;                   // 项目方赎回

// 视图函数
function isInExerciseWindow() external view returns (bool);
function isExpired() external view returns (bool);
function calculateUsdtPayment(uint256 amountWei) external view returns (uint256);
```

## 安全措施

1. **ReentrancyGuard**：防止重入攻击
2. **状态优先修改**：`exercise()` 先 burn Token，再转账
3. **时间限制**：严格的行权窗口和赎回时间检查
4. **权限控制**：`onlyIssuer` 限制敏感操作

## 快速开始

### 编译

```bash
forge build
```

### 运行所有测试

```bash
forge test
```

### 运行资金流测试（带详细输出）

```bash
forge test --match-test FundFlow -vvv
```

## 测试覆盖

| 测试 | 描述 |
|------|------|
| `test_Issue_MintsOptions1to1` | 验证 1:1 铸造 |
| `test_CannotExercise_BeforeExpiry` | 到期前不能行权 |
| `test_Exercise_OnExpiryWindow_Success` | 到期窗口内行权成功 |
| `test_Exercise_PartialAmount_Works` | 部分行权正确 |
| `test_CannotExercise_AfterWindow` | 窗口结束后不能行权 |
| `test_ReclaimExpired_OnlyIssuer_AndAfterWindow` | 赎回权限和时间检查 |
| `test_ERC20_TransferApproveTransferFrom_Works` | ERC20 标准功能 |
| `test_FundFlow_Issue_Deposit` | 存入资金流详解 |
| `test_FundFlow_Exercise_Complete` | 行权资金流详解 |
| `test_FundFlow_Reclaim_Expired` | 赎回资金流详解 |
| `test_FundFlow_FullLifecycle` | 完整生命周期 |
| `test_FundFlow_UnitConversion` | 单位换算验证 |

## 项目结构

```
EuropeanCallOption/
├── src/
│   ├── OptionToken.sol    # 期权 Token 合约
│   └── MockUSDT.sol       # 测试用 USDT
├── script/
│   └── DeployOption.s.sol # 部署脚本
├── test/
│   └── OptionToken.t.sol  # 测试套件
├── LOCAL_TESTING.md       # 详细手动测试指南
└── README.md
```

## 学习重点

本项目重点不在于期权定价，而是：

1. **生命周期管理**：状态机、时间窗口
2. **资金流控制**：存入、行权、赎回
3. **单位换算**：ETH (18位) vs USDT (6位)
4. **权限和时间限制**：onlyIssuer、时间窗口检查
5. **安全模式**：CEI (Checks-Effects-Interactions)

## License

MIT
