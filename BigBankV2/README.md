# BigBankV2

去中心化存款银行合约，支持直接 ETH 转账存款，使用**可迭代链表**维护前 10 名存款用户排行榜。

## ✨ 功能特性

- 💰 **直接转账存款**: 支持通过 MetaMask 直接向合约地址转账
- 📊 **实时排行榜**: 可迭代链表维护前 10 名存款用户
- 🔄 **动态更新**: 存款后自动更新排名
- 🎯 **最小存款**: 0.001 ETH 起存
- 🛡️ **管理功能**: Owner 可提现和转移管理权
- ✅ **完整测试**: 14 个测试用例全部通过

## 📁 项目结构

```
BigBankV2/
├── src/
│   └── BigBankV2.sol           # 主合约 (261 行)
├── test/
│   └── BigBankV2.t.sol         # 测试文件 (14 tests)
├── script/
│   └── Deploy.s.sol            # 部署脚本
└── frontend/                    # Vite + React 前端
    ├── src/
    │   ├── App.tsx             # 主应用
    │   ├── wagmi.ts            # Web3 配置
    │   └── components/         # React 组件
    └── package.json
```

## 🚀 快速开始

### 1. 安装依赖

```bash
# 安装 Foundry 依赖
forge install

# 安装前端依赖
cd frontend && npm install
```

### 2. 运行测试

```bash
# 运行所有测试
forge test

# 详细输出
forge test -vvv
```

**测试结果**: 14/14 通过 ✅

```
BigBankV2Test:
  ✅ test_DepositViaDeposit
  ✅ test_DepositViaReceive
  ✅ test_RevertIfDepositTooSmall
  ✅ test_MultipleDeposits
  ✅ test_SingleUserInTopList
  ✅ test_TopListSortedByBalance
  ✅ test_TopListMaxSize10
  ✅ test_TopListUpdatesOnAdditionalDeposit
  ✅ test_OnlyOwnerCanWithdraw
  ✅ test_OwnerWithdraw
  ✅ test_SetAdmin
  ✅ test_OnlyOwnerCanSetAdmin
  ✅ test_GetBalance
  ✅ test_GetMyBalance
  ✅ test_GetTotalBalance
```

### 3. 本地部署

```bash
# 终端 1: 启动 Anvil 本地节点
anvil

# 终端 2: 部署合约
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### 4. 配置前端

将部署输出的合约地址更新到 `frontend/src/wagmi.ts`:

```typescript
export const CONTRACT_ADDRESS = '0x...' as const;
```

### 5. 启动前端

```bash
cd frontend
npm run dev
```

访问 http://localhost:5173

### 6. 配置 MetaMask

- **添加网络**: 
  - RPC URL: `http://127.0.0.1:8545`
  - Chain ID: `31337`
  - Currency: `ETH`

- **导入测试账户**:
  ```
  私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
  ```

## 🔧 核心技术实现

### 1. 直接转账存款 (receive 函数)

合约支持两种存款方式：显式调用 `deposit()` 和直接转账。

```solidity
/// @notice 接收 ETH 存款（支持 MetaMask 直接转账）
receive() external payable {
    _deposit(msg.sender, msg.value);
}

/// @notice 显式存款函数
function deposit() external payable depositAmountValid {
    _deposit(msg.sender, msg.value);
}
```

**receive() 函数特点**:
- 当合约收到 ETH 且 calldata 为空时自动触发
- 允许用户通过钱包直接向合约地址转账
- 无需调用任何函数，更加便捷

**存款流程**:
```
用户通过 MetaMask 转账
    ↓
receive() 被触发
    ↓
_deposit(msg.sender, msg.value)
    ↓
更新 balances[user]
    ↓
触发 Deposit 事件
    ↓
更新链表排名
```

---

### 2. 可迭代链表实现 (核心数据结构)

#### 2.1 链表设计

**为什么使用链表?**
- ✅ 动态维护排序顺序
- ✅ 插入/删除操作高效
- ✅ 节省 gas (相比数组排序)
- ✅ 支持迭代遍历

**数据结构**:
```solidity
/// @notice 链表：每个地址指向下一个排名更低的地址
mapping(address => address) public nextDepositor;

/// @notice 链表头哨兵节点
address public constant HEAD = address(1);

/// @notice 当前链表大小
uint256 public listSize;

/// @notice 链表最大容量
uint256 public constant MAX_SIZE = 10;
```

**链表结构图**:
```
HEAD -> User1(10 ETH) -> User2(5 ETH) -> User3(2 ETH) -> HEAD
 ↑                                                          ↓
 └──────────────────────────────────────────────────────────┘
```

**哨兵节点 (HEAD) 的作用**:
- 简化边界条件处理
- 空链表: `nextDepositor[HEAD] = HEAD`
- 避免特殊处理第一个和最后一个节点

#### 2.2 链表初始化

```solidity
constructor() {
    owner = msg.sender;
    // 初始化链表头节点指向自身表示空链表
    nextDepositor[HEAD] = HEAD;
}
```

**初始状态**:
```
HEAD -> HEAD (空链表)
```

#### 2.3 插入操作 (按余额降序)

```solidity
/// @notice 按余额降序插入用户到链表
/// @dev 链表顺序: HEAD -> 最大 -> 第二大 -> ... -> 最小 -> HEAD
function _insertSorted(address user, uint256 balance) internal {
    // 1. 如果链表已满，检查是否有资格进入前10
    if (listSize >= MAX_SIZE) {
        uint256 lastBalance = _getLastBalance();
        if (balance <= lastBalance) {
            return; // 不够资格进入前10
        }
        // 移除最后一个，为新用户腾位置
        _removeLast();
    }
    
    // 2. 找到插入位置：找到第一个余额小于当前用户的节点
    address prev = HEAD;
    address current = nextDepositor[HEAD];
    
    while (current != HEAD && balances[current] >= balance) {
        prev = current;
        current = nextDepositor[current];
    }
    
    // 3. 在 prev 和 current 之间插入 user
    nextDepositor[user] = current;
    nextDepositor[prev] = user;
    listSize++;
}
```

**插入示例**:

**初始状态**:
```
HEAD -> User1(10 ETH) -> User2(5 ETH) -> HEAD
```

**插入 User3(7 ETH)**:
```
1. 遍历链表找位置:
   - prev = HEAD, current = User1(10 ETH)
   - 10 >= 7, 继续
   - prev = User1, current = User2(5 ETH)
   - 5 < 7, 停止

2. 插入:
   nextDepositor[User3] = User2
   nextDepositor[User1] = User3

3. 结果:
   HEAD -> User1(10 ETH) -> User3(7 ETH) -> User2(5 ETH) -> HEAD
```

#### 2.4 移除操作

```solidity
/// @notice 从链表中移除用户
function _removeFromList(address user) internal {
    address current = HEAD;
    while (nextDepositor[current] != HEAD) {
        if (nextDepositor[current] == user) {
            // 找到了，跳过该用户
            nextDepositor[current] = nextDepositor[user];
            nextDepositor[user] = address(0);
            listSize--;
            return;
        }
        current = nextDepositor[current];
    }
}
```

**移除示例**:

**初始状态**:
```
HEAD -> User1(10 ETH) -> User2(5 ETH) -> User3(2 ETH) -> HEAD
```

**移除 User2**:
```
1. 遍历找到 User2:
   - current = HEAD
   - nextDepositor[HEAD] = User1, 不是 User2
   - current = User1
   - nextDepositor[User1] = User2, 找到了!

2. 移除:
   nextDepositor[User1] = nextDepositor[User2] = User3
   nextDepositor[User2] = address(0)
   listSize--

3. 结果:
   HEAD -> User1(10 ETH) -> User3(2 ETH) -> HEAD
```

#### 2.5 检查用户是否在链表中

```solidity
/// @notice 检查用户是否在链表中
function _isInList(address user) internal view returns (bool) {
    if (user == HEAD || user == address(0)) return false;
    
    address current = nextDepositor[HEAD];
    while (current != HEAD) {
        if (current == user) {
            return true;
        }
        current = nextDepositor[current];
    }
    return false;
}
```

**时间复杂度**: O(n)，其中 n 最大为 10

#### 2.6 获取最后一个元素

```solidity
/// @notice 获取链表最后一个元素的余额
function _getLastBalance() internal view returns (uint256) {
    address current = nextDepositor[HEAD];
    address last = HEAD;
    
    while (current != HEAD) {
        last = current;
        current = nextDepositor[current];
    }
    
    return last == HEAD ? 0 : balances[last];
}
```

#### 2.7 移除最后一个元素

```solidity
/// @notice 移除链表最后一个元素
function _removeLast() internal {
    address current = HEAD;
    address prev = HEAD;
    
    while (nextDepositor[current] != HEAD) {
        prev = current;
        current = nextDepositor[current];
    }
    
    if (current != HEAD) {
        nextDepositor[prev] = HEAD;
        nextDepositor[current] = address(0);
        listSize--;
    }
}
```

---

### 3. 存款逻辑与链表更新

#### 3.1 完整存款流程

```solidity
/// @notice 内部存款逻辑
function _deposit(address user, uint256 amount) internal {
    // 1. 验证最小存款金额
    require(amount >= MIN_DEPOSIT, "Deposit must be >= 0.001 ETH");
    
    // 2. 更新余额
    uint256 oldBalance = balances[user];
    balances[user] += amount;
    uint256 newBalance = balances[user];
    
    // 3. 触发事件
    emit Deposit(user, amount, newBalance);
    
    // 4. 更新链表
    _updateLinkedList(user, oldBalance, newBalance);
}
```

#### 3.2 链表更新策略

```solidity
/// @notice 更新链表中用户的位置
function _updateLinkedList(
    address user,
    uint256 oldBalance,
    uint256 newBalance
) internal {
    // 如果用户已在链表中，先移除
    if (oldBalance > 0 && _isInList(user)) {
        _removeFromList(user);
    }
    
    // 插入到正确位置
    _insertSorted(user, newBalance);
}
```

**为什么要先移除再插入?**
- 用户余额变化后，排名可能改变
- 先移除旧位置，再插入新位置
- 保证链表始终有序

**完整流程示例**:

**初始状态**:
```
HEAD -> User1(10 ETH) -> User2(5 ETH) -> User3(2 ETH) -> HEAD
```

**User3 存款 10 ETH (总余额 12 ETH)**:
```
1. oldBalance = 2 ETH, newBalance = 12 ETH
2. _isInList(User3) = true
3. _removeFromList(User3):
   HEAD -> User1(10 ETH) -> User2(5 ETH) -> HEAD
4. _insertSorted(User3, 12 ETH):
   HEAD -> User3(12 ETH) -> User1(10 ETH) -> User2(5 ETH) -> HEAD
```

---

### 4. 前 10 名限制机制

#### 4.1 容量检查

```solidity
if (listSize >= MAX_SIZE) {
    // 获取最后一个元素的余额
    uint256 lastBalance = _getLastBalance();
    if (balance <= lastBalance) {
        return; // 不够资格进入前10
    }
    // 移除最后一个，为新用户腾位置
    _removeLast();
}
```

**场景分析**:

**场景 1: 链表未满 (listSize < 10)**
- 直接插入，无需移除

**场景 2: 链表已满，新用户余额 > 最后一名**
- 移除最后一名
- 插入新用户

**场景 3: 链表已满，新用户余额 <= 最后一名**
- 不插入，直接返回

**示例**:

**当前前 10 名** (最后一名 1 ETH):
```
HEAD -> User1(10) -> ... -> User10(1) -> HEAD
```

**新用户存款 0.5 ETH**:
```
0.5 <= 1, 不够资格，不插入
```

**新用户存款 2 ETH**:
```
2 > 1, 有资格
1. 移除 User10
2. 插入新用户到正确位置
```

---

### 5. 查询功能

#### 5.1 获取前 10 名

```solidity
/// @notice 获取前10名存款用户
function getTopDepositors()
    external
    view
    returns (address[] memory users, uint256[] memory amounts)
{
    users = new address[](listSize);
    amounts = new uint256[](listSize);
    
    address current = nextDepositor[HEAD];
    uint256 index = 0;
    
    while (current != HEAD && index < listSize) {
        users[index] = current;
        amounts[index] = balances[current];
        current = nextDepositor[current];
        index++;
    }
    
    return (users, amounts);
}
```

**遍历链表**:
```
1. 从 HEAD 开始
2. 依次访问 nextDepositor[current]
3. 直到回到 HEAD 或达到 listSize
```

**返回数据**:
- `users`: 地址数组，按余额降序
- `amounts`: 对应的余额数组

#### 5.2 其他查询函数

```solidity
/// @notice 获取用户余额
function getBalance(address user) external view returns (uint256) {
    return balances[user];
}

/// @notice 获取自己的余额
function getMyBalance() external view returns (uint256) {
    return balances[msg.sender];
}

/// @notice 获取合约总余额
function getTotalBalance() external view returns (uint256) {
    return address(this).balance;
}
```

---

### 6. 管理功能

#### 6.1 提现

```solidity
/// @notice 管理员提现
function withdraw(uint256 amount, address payable to) external onlyOwner {
    require(amount > 0, "Amount must be > 0");
    require(
        address(this).balance >= amount,
        "Insufficient contract balance"
    );
    
    (bool ok, ) = to.call{value: amount}("");
    require(ok, "Transfer failed");
    
    emit Withdraw(to, amount);
}
```

**安全考虑**:
- 仅 owner 可调用
- 验证金额 > 0
- 验证合约余额充足
- 使用 `call{value}()` 转账
- 检查转账成功

#### 6.2 转移管理权

```solidity
/// @notice 转移管理员
function setAdmin(address newAdmin) external onlyOwner {
    require(newAdmin != address(0), "Invalid admin address");
    address oldAdmin = owner;
    owner = newAdmin;
    emit AdminChanged(oldAdmin, newAdmin);
}
```

---

## 📊 数据结构对比

### 链表 vs 数组

| 特性 | 链表 | 数组 |
|------|------|------|
| 插入 (有序) | O(n) | O(n) + 排序 |
| 删除 | O(n) | O(n) + 移动元素 |
| 查询第 k 个 | O(k) | O(1) |
| 遍历全部 | O(n) | O(n) |
| Gas 成本 | 较低 | 较高 (排序) |
| 存储成本 | mapping | 动态数组 |

**为什么选择链表?**
- ✅ 插入/删除不需要移动其他元素
- ✅ 不需要排序操作
- ✅ Gas 成本更低
- ✅ 适合动态排名场景

---

## 🎨 前端功能

### 主要功能

| 功能 | 说明 |
|------|------|
| 连接钱包 | RainbowKit + wagmi |
| 存款 | 支持输入金额或直接转账 |
| 查看余额 | 显示个人余额和合约总额 |
| 排行榜 | 实时显示前 10 名 |
| 管理员 | Owner 可提现和转移权限 |

### 核心代码示例

```typescript
// 存款
const { writeContract } = useWriteContract();

const handleDeposit = () => {
    writeContract({
        address: CONTRACT_ADDRESS,
        abi: CONTRACT_ABI,
        functionName: 'deposit',
        value: parseEther(amount)
    });
};

// 查询前 10 名
const { data: topDepositors } = useReadContract({
    address: CONTRACT_ADDRESS,
    abi: CONTRACT_ABI,
    functionName: 'getTopDepositors'
});
```

---

## 🧪 测试用例

### 存款测试 (4 tests)
- ✅ `test_DepositViaDeposit` - 通过 deposit() 存款
- ✅ `test_DepositViaReceive` - 通过直接转账存款
- ✅ `test_RevertIfDepositTooSmall` - 最小金额验证
- ✅ `test_MultipleDeposits` - 多次存款累加

### 链表测试 (4 tests)
- ✅ `test_SingleUserInTopList` - 单用户排行榜
- ✅ `test_TopListSortedByBalance` - 排序正确性
- ✅ `test_TopListMaxSize10` - 最大容量限制
- ✅ `test_TopListUpdatesOnAdditionalDeposit` - 动态更新

### 管理功能测试 (4 tests)
- ✅ `test_OnlyOwnerCanWithdraw` - 权限验证
- ✅ `test_OwnerWithdraw` - 提现功能
- ✅ `test_SetAdmin` - 转移管理权
- ✅ `test_OnlyOwnerCanSetAdmin` - 权限验证

### 查询功能测试 (2 tests)
- ✅ `test_GetBalance` - 查询余额
- ✅ `test_GetMyBalance` - 查询自己余额
- ✅ `test_GetTotalBalance` - 查询合约总额

---

## 🛠️ 技术栈

### 智能合约
- **Solidity**: 0.8.20
- **框架**: Foundry
- **测试**: Forge Test
- **数据结构**: 可迭代链表

### 前端
- **框架**: Vite + React + TypeScript
- **Web3**: wagmi v2 + viem
- **钱包**: RainbowKit
- **UI**: TailwindCSS + 深色主题

---

## 🔍 关键问题解决

### 1. 为什么使用哨兵节点 (HEAD)?

**问题**: 链表操作需要处理很多边界情况
- 空链表
- 插入第一个元素
- 删除最后一个元素

**解决方案**: 使用哨兵节点
```solidity
address public constant HEAD = address(1);

constructor() {
    nextDepositor[HEAD] = HEAD;  // 空链表
}
```

**优点**:
- ✅ 简化边界条件
- ✅ 统一插入/删除逻辑
- ✅ 避免特殊判断

### 2. 为什么选择 address(1) 作为 HEAD?

**原因**:
- `address(0)` 是默认值，用于表示"未设置"
- `address(1)` 不太可能是真实用户地址
- 避免与用户地址冲突

### 3. 如何保证链表始终有序?

**策略**:
1. 插入时按余额降序查找位置
2. 用户再次存款时，先移除旧位置，再插入新位置
3. 每次操作后链表自动保持有序

### 4. 为什么不使用数组 + 排序?

**数组方案的问题**:
- 每次插入需要排序 (O(n log n))
- 删除元素需要移动后续元素
- Gas 成本高

**链表方案的优势**:
- 插入/删除只需调整指针 (O(n))
- 不需要排序操作
- Gas 成本更低

---

## 📝 License

MIT

## 🙏 致谢

- [Foundry](https://getfoundry.sh/) - 智能合约开发框架
- [OpenZeppelin](https://www.openzeppelin.com/) - 安全的智能合约库
- [wagmi](https://wagmi.sh/) - React Hooks for Ethereum
