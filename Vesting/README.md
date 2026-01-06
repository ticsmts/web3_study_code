# Vesting 代币授权释放合约项目

本项目实现了一个具备 **12个月 Cliff（锁定/断崖期）** 以及 **24个月线性按月解锁（每月释放 1/24）** 逻辑的 ERC20 代币授权释放合约。

## 1. 核心功能与参数

- **受益人 (Beneficiary)**: 最终接收代币的地址。
- **代币地址 (Token Address)**: 锁定的 ERC20 代币合约地址。
- **锁定总量**: 合约内部锁定的代币总额（本项目测试中为 1,000,000 枚）。
- **释放逻辑**:
    - **Cliff (12个月)**: 在部署后的前 12 个月内，没有任何代币可以释放。
    - **线性释放 (24个月)**: 从第 13 个月开始，每月解锁总额的 1/24。到第 36 个月末，代币全部释放完毕。
    - **release() 方法**: 受益人或任何人均可触发，将当前已解锁但未领取的代币转账给受益人。

## 2. 技术重难点与实现细节

### 2.1 离散型线性释放逻辑 (Discrete Linear Release)
**难度**：⭐⭐
**核心逻辑**：
与每秒线性释放不同，本项目要求**每月**解锁 1/24。这意味着在同一个月内，无论何时调用 `release()`，已解锁的总额应该是相同的。
- **公式分析**：`vestedMonths = ((block.timestamp - start) / 30 days) - 12 + 1`
- **代码实现**：
  ```solidity
  uint256 monthsPassed = (timestamp - start) / MONTH_IN_SECONDS;
  uint256 monthsSinceCliffStarted = monthsPassed - CLIFF_MONTHS;
  uint256 vestedMonths = monthsSinceCliffStarted + 1; 
  ```
  通过整数除法 `(timestamp - start) / 30 days` 自动实现了“向下取整”，从而保证了在一个月（30天）的周期内，计算出的 `monthsPassed` 是恒定的，直到下一个 30 天周期开始。

### 2.2 动态总额计算 (Total Allocation Accuracy)
**难度**：⭐⭐⭐
**挑战**：
如果直接使用 `token.balanceOf(address(this))` 来计算释放比例，会有一个陷阱：随着代币不断被 `release()`，合约余额会减少，导致后续计算比例时的基数错误。
- **解决方案**：引入 `released` 变量记录历史已释放总量。
- **计算逻辑**：`totalAllocation = token.balanceOf(address(this)) + released`
  这样无论何时计算，`totalAllocation` 始终等于最初转入合约的 1,000,000 枚代币。

### 2.3 精度损失处理 (Precision Handling)
**难度**：⭐
**注意事项**：
在 Solidity 中，必须**先乘法后除法**以保持精度。
- **正确做法**：`(totalAllocation * vestedMonths) / VESTING_MONTHS`
- **边界处理**：当 `vestedMonths >= 24` 时，直接返回 `totalAllocation`，防止因除法不整除导致的极其微小的代币残留在合约中。

## 3. Foundry 时间模拟测试 (Testing Re-entrancy of Time)

### 核心 Cheatcodes：`vm.warp`
**重难点**：
在测试增量释放（`test_IncrementalRelease`）时，`vm.warp` 修改的是全局状态。
- **易错点**：如果在循环中使用 `vm.warp(block.timestamp + 30 days)`，必须确保循环逻辑不会因为多次偏移导致对齐偏差。
- **最佳实践**：在测试开始时记录 `startTime`，然后使用绝对偏移 `vm.warp(startTime + Offset)` 来确保每个测试点的时间戳精确无误。

```solidity
uint256 startTime = block.timestamp;
for (uint256 i = 0; i < 24; i++) {
    vm.warp(startTime + (12 + i) * 30 days); // 绝对时间模拟
    vesting.release();
    // ... 验证逻辑
}
```

### 核心测试代码解析 (`Vesting.t.sol`):

- **vm.warp(timestamp)**: 强制将区块链的 `block.timestamp` 修改为指定的时间戳。
- **vm.expectRevert**: 验证在锁定期间（例如第 11 个月）调用 `release()` 是否会因无代币可领而报错。

#### 测试场景覆盖：
1. **断崖期保护测试**: `vm.warp(start + 11个月)`，验证无法领取。
2. **首月解锁测试**: `vm.warp(start + 12个月)`，验证领取金额恰好为 `1,000,000 / 24`。
3. **中期解锁测试**: `vm.warp(start + 23个月)`，即第 24 个月初，验证领取总额达到 `500,000` (50%)。
4. **全额释放测试**: `vm.warp(start + 36个月)`，验证最终所有代币均可领取，且合约余额归零。

## 4. 如何运行

1. **环境准备**: 确保已安装 Foundry。
2. **安装依赖**:
   ```bash
   forge install OpenZeppelin/openzeppelin-contracts --no-git
   ```
3. **运行测试**:
   ```bash
   forge test -vv
   ```

## 5. 项目结构说明

- `src/Vesting.sol`: 业务逻辑合约。
- `src/MockERC20.sol`: 测试用标准 ERC20 代币合约。
- `test/Vesting.t.sol`: 包含详细注释的 Foundry 测试代码，模拟时间流逝。
