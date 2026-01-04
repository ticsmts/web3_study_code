# Inscription Contract Factory

基于 UUPS 代理模式的可升级铭文工厂合约，支持部署和铸造 ERC20 铭文代币。

## ✨ 功能特性

### 智能合约
- 🔄 **UUPS 可升级架构**: 工厂合约支持无缝升级
- 📝 **V1 免费铭文**: 使用 `new` 部署，免费铸造
- 💰 **V2 付费铸造**: ERC1167 最小代理部署，支持设置铸造价格
- ⚡ **Gas 优化**: V2 部署成本降低 ~97.7%
- 💸 **收益提取**: Owner 可提取累计铸造费用
- 🛡️ **完整测试覆盖**: 19 个测试用例全部通过

### 前端应用
- 🎨 **现代化 UI**: Vite + React + TailwindCSS
- 🦊 **钱包集成**: ethers.js + MetaMask
- 📋 **部署铭文**: 支持 V1/V2 两种部署模式
- 🎯 **铸造功能**: 免费/付费铸造切换
- 💰 **收益管理**: Owner 提取累计费用

## 📁 项目结构

```
InscriptionContractFactory/
├── src/                                # 智能合约源码
│   ├── InscriptionFactoryV1.sol        # V1: 使用 new 部署
│   ├── InscriptionFactoryV2.sol        # V2: ERC1167 + 付费铸造
│   ├── InscriptionToken.sol            # V1 代币合约
│   └── InscriptionTokenV2.sol          # V2 代币合约 (可初始化)
├── script/                              # 部署脚本
│   ├── DeployFactoryV1.s.sol           # 部署 V1 + 代理
│   └── UpgradeToV2.s.sol               # 升级到 V2
├── test/                                # 测试文件
│   ├── InscriptionFactoryV1.t.sol      # V1 测试 (10 tests)
│   └── InscriptionFactoryV2.t.sol      # V2 测试 (9 tests)
└── frontend/                            # Vite 前端
    ├── src/
    │   ├── App.jsx                     # 主应用
    │   ├── contract.js                 # 合约配置
    │   └── components/                 # React 组件
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

**测试结果**: 19/19 通过 ✅

```
InscriptionFactoryV1Test: 10 passed
InscriptionFactoryV2Test: 9 passed
```

### 3. 本地部署

```bash
# 终端 1: 启动 Anvil 本地节点
anvil

# 终端 2: 部署 V1 合约
forge script script/DeployFactoryV1.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# 升级到 V2 (可选)
$env:FACTORY_PROXY="<代理地址>"; forge script script/UpgradeToV2.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### 4. 启动前端

```bash
cd frontend
npm run dev
```

访问 http://localhost:5173

## 🔧 核心技术实现

### 1. UUPS 可升级模式

```solidity
// InscriptionFactoryV1.sol
contract InscriptionFactoryV1 is 
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // 禁用实现合约初始化
    constructor() {
        _disableInitializers();
    }
    
    // 初始化函数替代构造函数
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }
    
    // 仅 owner 可升级
    function _authorizeUpgrade(address newImplementation) 
        internal override onlyOwner {}
}
```

**升级流程**:
1. 部署新实现合约 `InscriptionFactoryV2`
2. 调用代理的 `upgradeToAndCall(newImpl, initData)`
3. 代理存储保持不变，逻辑指向新实现

> 📖 **详细部署说明**: 查看 [DEPLOYMENT.md](./DEPLOYMENT.md) 了解完整的 UUPS 代理部署、升级流程和 Sepolia 测试网配置。

---

### 2. V1 部署方式 (使用 `new`)

V1 采用传统的 `new` 方式部署每个铭文代币合约。

```solidity
// InscriptionFactoryV1.sol

function deployInscription(
    string memory symbol,
    uint256 totalSupply,
    uint256 perMint
) external returns (address tokenAddress) {
    // 1. 参数验证
    if (bytes(symbol).length == 0 || totalSupply == 0 || perMint == 0) {
        revert InvalidParameters();
    }
    
    // 2. 使用 new 部署新代币合约
    InscriptionToken token = new InscriptionToken(
        symbol,      // name
        symbol,      // symbol
        totalSupply,
        perMint,
        address(this) // factory
    );
    
    tokenAddress = address(token);
    
    // 3. 记录铭文信息
    inscriptions[tokenAddress] = InscriptionInfo({
        creator: msg.sender,
        symbol: symbol,
        totalSupply: totalSupply,
        perMint: perMint,
        exists: true
    });
    
    allInscriptions.push(tokenAddress);
    
    emit InscriptionDeployed(tokenAddress, msg.sender, symbol, totalSupply, perMint);
}
```

**V1 特点**:
- ✅ 简单直接，逻辑清晰
- ✅ 每个代币是独立的完整合约
- ❌ 部署成本高 (~2,100,000 gas)
- ❌ 占用更多区块链存储空间

**铸造流程**:

```solidity
function mintInscription(address tokenAddr) external {
    InscriptionInfo storage info = inscriptions[tokenAddr];
    if (!info.exists) revert InscriptionNotFound();
    
    // 调用代币合约的 mint 函数
    InscriptionToken(tokenAddr).mint(msg.sender);
    
    emit InscriptionMinted(tokenAddr, msg.sender, info.perMint);
}
```

---

### 3. ERC1167 最小代理 (V2 核心优化)

V2 使用 **ERC1167 最小代理标准** (Minimal Proxy / Clone) 实现极低成本的代币部署。

#### 3.1 什么是 ERC1167?

ERC1167 是一种极简的代理合约标准，用于以极低的成本部署多个相同逻辑的合约实例。

**核心思想**:
- 部署一个**实现合约** (Implementation) 包含所有业务逻辑
- 为每个铭文部署一个**极小的代理合约** (Clone)
- 代理合约通过 `delegatecall` 调用实现合约的逻辑
- 每个代理有自己独立的存储空间

#### 3.2 字节码分析

ERC1167 代理合约的完整字节码只有 **45 字节**:

```
363d3d373d3d3d363d73bebebebebebebebebebebebebebebebebebebebe5af43d82803e903d91602b57fd5bf3
```

**字节码解析**:
```
36       - CALLDATASIZE    // 获取 calldata 大小
3d       - RETURNDATASIZE  // 0 (初始化)
3d       - RETURNDATASIZE  // 0
37       - CALLDATACOPY    // 复制 calldata 到内存
3d       - RETURNDATASIZE  // 0
3d       - RETURNDATASIZE  // 0
3d       - RETURNDATASIZE  // 0
36       - CALLDATASIZE    // calldata 大小
3d       - RETURNDATASIZE  // 0
73bebe...be - PUSH20 <implementation_address>  // 实现合约地址 (20 字节)
5a       - GAS             // 剩余 gas
f4       - DELEGATECALL    // 委托调用
3d       - RETURNDATASIZE  // 获取返回数据大小
82       - DUP3
80       - DUP1
3e       - RETURNDATACOPY  // 复制返回数据
90       - SWAP1
3d       - RETURNDATASIZE
91       - SWAP2
602b     - PUSH1 0x2b      // 跳转目标
57       - JUMPI           // 条件跳转
fd       - REVERT          // 失败则 revert
5b       - JUMPDEST        // 跳转目标
f3       - RETURN          // 返回数据
```

#### 3.3 V2 部署实现

```solidity
// InscriptionFactoryV2.sol
import "@openzeppelin/contracts/proxy/Clones.sol";

contract InscriptionFactoryV2 is InscriptionFactoryV1 {
    using Clones for address;
    
    address public tokenImplementation;  // TokenV2 实现合约地址
    
    // V2 初始化
    function initializeV2(address _tokenImplementation) external reinitializer(2) {
        require(tokenImplementation == address(0), "Already initialized");
        tokenImplementation = _tokenImplementation;
    }
    
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price  // 新增: 铸造价格
    ) public returns (address tokenAddress) {
        // 1. 参数验证
        if (bytes(symbol).length == 0 || totalSupply == 0 || perMint == 0) {
            revert InvalidParameters();
        }
        
        // 2. 克隆实现合约 (仅 45 字节!)
        address clone = tokenImplementation.clone();
        
        // 3. 初始化克隆合约
        InscriptionTokenV2(clone).initialize(
            symbol,
            symbol,
            totalSupply,
            perMint,
            address(this)
        );
        
        tokenAddress = clone;
        
        // 4. 记录基础信息 (V1 兼容)
        inscriptions[tokenAddress] = InscriptionInfo({
            creator: msg.sender,
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            exists: true
        });
        
        // 5. 记录 V2 扩展信息
        inscriptionsV2[tokenAddress] = InscriptionInfoV2({
            price: price,
            isV2: true
        });
        
        allInscriptions.push(tokenAddress);
        
        emit InscriptionDeployedV2(tokenAddress, msg.sender, symbol, totalSupply, perMint, price);
    }
}
```

#### 3.4 成本对比

| 部署方式 | Gas 成本 | 字节码大小 | 节省比例 |
|---------|---------|-----------|---------|
| **V1 (new)** | ~2,100,000 | ~10 KB | - |
| **V2 (Clone)** | ~48,000 | 45 bytes | **~97.7%** |

**实际测试数据**:
- V1 部署一个铭文: 2,100,000 gas
- V2 克隆一个铭文: 48,000 gas
- **节省**: 2,052,000 gas (~97.7%)

#### 3.5 执行流程

```
用户调用 clone.mint(user)
    ↓
Clone 合约 (45 bytes)
    ↓ delegatecall
Implementation 合约 (完整逻辑)
    ↓ 在 Clone 的存储上下文中执行
    ↓ msg.sender = 原始调用者
    ↓ address(this) = Clone 地址
    ↓
修改 Clone 的存储
    ↓
返回结果给用户
```

**关键点**:
- `delegatecall` 保持调用者上下文
- 存储操作发生在 Clone 合约
- 每个 Clone 有独立的状态

#### 3.6 Token 合约对比

**InscriptionToken (V1):**
```solidity
contract InscriptionToken is ERC20 {
    // 使用 constructor 初始化
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _perMint,
        address _factory
    ) ERC20(_name, _symbol) {
        maxSupply = _maxSupply;
        perMint = _perMint;
        factory = _factory;
    }
}
```

**InscriptionTokenV2 (V2):**
```solidity
contract InscriptionTokenV2 is Initializable, ERC20Upgradeable {
    // 禁用 constructor
    constructor() {
        _disableInitializers();
    }
    
    // 使用 initialize 替代 constructor
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _perMint,
        address _factory
    ) external initializer {
        __ERC20_init(_name, _symbol);
        maxSupply = _maxSupply;
        perMint = _perMint;
        factory = _factory;
    }
}
```

**为什么 V2 必须使用 `initialize()`?**
- Clone 部署时不会调用 `constructor`
- `constructor` 只在实现合约部署时执行一次
- 每个 Clone 需要独立初始化自己的状态

---

### 4. 付费铸造机制

V2 支持在部署铭文时设置铸造价格，用户铸造时需支付 ETH。

#### 4.1 数据结构设计

```solidity
// V1 基础信息 (所有铭文共享)
struct InscriptionInfo {
    address creator;
    string symbol;
    uint256 totalSupply;
    uint256 perMint;
    bool exists;
}
mapping(address => InscriptionInfo) public inscriptions;

// V2 扩展信息 (仅 V2 铭文)
struct InscriptionInfoV2 {
    uint256 price;      // 铸造价格 (wei)
    bool isV2;          // 是否为 V2 铭文
}
mapping(address => InscriptionInfoV2) public inscriptionsV2;

// 累计收益
uint256 public totalFees;
```

#### 4.2 铸造时收费

```solidity
function mintInscription(address tokenAddr) external payable {
    // 1. 验证铭文存在
    InscriptionInfo storage info = inscriptions[tokenAddr];
    if (!info.exists) revert InscriptionNotFound();
    
    // 2. 获取 V2 信息
    InscriptionInfoV2 storage infoV2 = inscriptionsV2[tokenAddr];
    
    // 3. 处理付费逻辑
    if (infoV2.isV2 && infoV2.price > 0) {
        // V2 付费铭文
        if (msg.value != infoV2.price) {
            revert InvalidPayment();  // 支付金额必须精确匹配
        }
        
        // 累加到总收益
        totalFees += msg.value;
        
        // 调用 V2 token 的 mint
        InscriptionTokenV2(tokenAddr).mint(msg.sender);
    } else {
        // V1 免费铭文 或 V2 免费铭文
        if (msg.value > 0) {
            revert InvalidPayment();  // 免费铭文不接受 ETH
        }
        
        // 调用 V1 token 的 mint
        InscriptionToken(tokenAddr).mint(msg.sender);
    }
    
    emit InscriptionMinted(tokenAddr, msg.sender, info.perMint);
}
```

#### 4.3 支付流程图

```
用户调用 mintInscription(tokenAddr) { value: 0.01 ether }
    ↓
检查 inscriptions[tokenAddr].exists ✓
    ↓
获取 inscriptionsV2[tokenAddr]
    ↓
判断 isV2 && price > 0 ✓
    ↓
验证 msg.value == price
    ↓ 0.01 ether == 0.01 ether ✓
累加 totalFees += 0.01 ether
    ↓
调用 InscriptionTokenV2(tokenAddr).mint(msg.sender)
    ↓
Token 合约检查供应量 ✓
    ↓
铸造 perMint 数量给用户
    ↓
emit InscriptionMinted(...)
    ↓
返回成功
```

---

### 5. 收益提取机制

Owner 可以提取累计的铸造费用。

#### 5.1 提取函数实现

```solidity
function withdrawFees() external onlyOwner {
    // 1. 获取当前累计金额
    uint256 amount = totalFees;
    
    // 2. 验证有收益可提取
    if (amount == 0) revert InvalidParameters();
    
    // 3. 先清零 (防止重入攻击)
    totalFees = 0;
    
    // 4. 转账给 owner
    (bool success, ) = owner().call{value: amount}("");
    
    // 5. 验证转账成功
    if (!success) revert TransferFailed();
    
    // 6. 触发事件
    emit FeesWithdrawn(owner(), amount);
}
```

#### 5.2 安全模式: Checks-Effects-Interactions

**标准模式**:
```solidity
function withdrawFees() external onlyOwner {
    // ✅ Checks: 检查条件
    uint256 amount = totalFees;
    if (amount == 0) revert InvalidParameters();
    
    // ✅ Effects: 修改状态
    totalFees = 0;  // 先清零!
    
    // ✅ Interactions: 外部调用
    (bool success, ) = owner().call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

**为什么要先清零?**

**错误示例 (重入攻击)**:
```solidity
// ❌ 危险: 先转账后清零
function withdrawFees() external onlyOwner {
    uint256 amount = totalFees;
    
    // 1. 先转账
    (bool success, ) = owner().call{value: amount}("");
    
    // 2. 后清零 (攻击者可在此之前重入)
    totalFees = 0;
}
```

**攻击场景**:
```
1. 攻击者 (owner) 调用 withdrawFees()
2. 合约转账 1 ETH 给攻击者
3. 攻击者的 receive() 被触发
4. 攻击者在 receive() 中再次调用 withdrawFees()
5. totalFees 还是 1 ETH (未清零)
6. 合约再次转账 1 ETH
7. 重复...直到合约余额耗尽
```

**正确做法**:
```solidity
// ✅ 安全: 先清零后转账
totalFees = 0;           // 1. 先清零
(bool success, ) = ...;  // 2. 再转账
// 即使重入，totalFees 已经是 0，无法再次提取
```

#### 5.3 转账方式对比

| 方式 | Gas Limit | 失败处理 | 安全性 | 推荐 |
|------|-----------|---------|--------|------|
| `transfer()` | 2300 gas | 自动 revert | 高 | ❌ 过时 |
| `send()` | 2300 gas | 返回 false | 中 | ❌ 不推荐 |
| `call{value}()` | 全部 gas | 返回 false | 需手动检查 | ✅ 推荐 |

**为什么使用 `call{value}()`?**
```solidity
// ✅ 推荐: call (灵活，兼容性好)
(bool success, ) = owner().call{value: amount}("");
if (!success) revert TransferFailed();

// ❌ 过时: transfer (gas 限制可能导致失败)
owner().transfer(amount);  // 仅 2300 gas，可能不够

// ❌ 不推荐: send (需手动检查)
bool success = owner().send(amount);
if (!success) revert TransferFailed();
```

---

### 6. 向后兼容性设计

V2 完全兼容 V1 部署的铭文，升级后 V1 铭文仍可正常使用。

**V1 数据结构**:
```solidity
struct InscriptionInfo {
    address creator;
    string symbol;
    uint256 totalSupply;
    uint256 perMint;
    bool exists;
}
mapping(address => InscriptionInfo) public inscriptions;
```

**V2 扩展 (不修改 V1 结构)**:
```solidity
// 保留 V1 mapping
mapping(address => InscriptionInfo) public inscriptions;

// 新增 V2 mapping
struct InscriptionInfoV2 {
    uint256 price;
    bool isV2;
}
mapping(address => InscriptionInfoV2) public inscriptionsV2;
```

**兼容性处理**:
```solidity
function getInscriptionInfo(address tokenAddr) external view returns (...) {
    InscriptionInfo storage info = inscriptions[tokenAddr];
    InscriptionInfoV2 storage infoV2 = inscriptionsV2[tokenAddr];
    
    if (infoV2.isV2) {
        // V2 铭文: 使用 InscriptionTokenV2
        InscriptionTokenV2 token = InscriptionTokenV2(tokenAddr);
        return (..., token.totalMinted(), token.remainingSupply());
    } else {
        // V1 铭文: 使用 InscriptionToken
        InscriptionToken token = InscriptionToken(tokenAddr);
        return (..., token.totalMinted(), token.remainingSupply());
    }
}
```

## 🎨 前端功能

### 主要功能

| 功能 | 说明 |
|------|------|
| 部署铭文 | 支持 V1 免费 / V2 付费两种模式 |
| 铸造铭文 | 根据铭文类型自动切换免费/付费 |
| 查看列表 | 显示所有已部署的铭文及状态 |
| 提取收益 | Owner 提取累计铸造费用 |

### 核心代码示例

```javascript
// 部署 V2 付费铭文
const deployInscription = async () => {
    const tx = await factoryContract.deployInscription(
        symbol,
        totalSupply,
        perMint,
        ethers.parseEther(price)  // 设置铸造价格
    );
    await tx.wait();
};

// 铸造铭文 (付费)
const mintInscription = async (tokenAddress, price) => {
    const tx = await factoryContract.mintInscription(
        tokenAddress,
        { value: ethers.parseEther(price) }  // 支付 ETH
    );
    await tx.wait();
};

// 提取收益 (仅 Owner)
const withdrawFees = async () => {
    const tx = await factoryContract.withdrawFees();
    await tx.wait();
};
```

## 📊 合约地址

### Sepolia Testnet

| 合约 | 地址 | Etherscan |
|------|------|-----------| | 代理合约 (Proxy) | `0x50180de3322F3309Db32f19D5537C3698EEE9078` | [查看](https://sepolia.etherscan.io/address/0x50180de3322F3309Db32f19D5537C3698EEE9078) |
| V1 实现 | `0xcea66d15f6800Ea380D09a649dAA02E6B5ec963c` | [查看](https://sepolia.etherscan.io/address/0xcea66d15f6800Ea380D09a649dAA02E6B5ec963c) |
| V2 实现 | `0x2227B9300ED19eAdFF91DBd7f536dD45D1A84e6f` | [查看](https://sepolia.etherscan.io/address/0x2227b9300ed19eadff91dbd7f536dd45d1a84e6f) |
| TokenV2 实现 | `0x5C86ccaebE69f50DC23c4c44d66597D39ed9ab55` | [查看](https://sepolia.etherscan.io/address/0x5C86ccaebE69f50DC23c4c44d66597D39ed9ab55) |

## 🧪 测试用例

### InscriptionFactoryV1Test (10 tests)
- ✅ `test_DeployInscription_Success` - 部署成功
- ✅ `test_DeployInscription_Fail_InvalidParams` - 参数验证
- ✅ `test_MintInscription_Success` - 铸造成功
- ✅ `test_MintInscription_Fail_ExceedsSupply` - 超出供应量
- ✅ `test_GetInscriptionInfo` - 查询信息
- ✅ `test_GetInscriptionsCount` - 统计数量
- ✅ `test_Version` - 版本检查
- ✅ 其他边界测试...

### InscriptionFactoryV2Test (9 tests)
- ✅ `test_DeployWithPrice_Success` - 付费部署成功
- ✅ `test_MintWithPayment_Success` - 付费铸造成功
- ✅ `test_MintWithPayment_Fail_WrongAmount` - 支付金额错误
- ✅ `test_WithdrawFees_Success` - 提取收益成功
- ✅ `test_WithdrawFees_Fail_OnlyOwner` - 权限验证
- ✅ `test_Upgrade_PreservesState` - 升级保持状态
- ✅ `test_V1Compatibility` - V1 兼容性
- ✅ 其他测试...

## 🛠️ 技术栈

### 智能合约
- **Solidity**: ^0.8.28
- **框架**: Foundry
- **升级模式**: OpenZeppelin UUPS
- **代理标准**: ERC1167 Minimal Proxy
- **库**: OpenZeppelin Contracts Upgradeable

### 前端
- **框架**: Vite + React
- **Web3**: ethers.js v6
- **UI**: TailwindCSS
- **钱包**: MetaMask

## 🔍 关键问题解决

### 1. 为什么选择 ERC1167 而非直接部署?

**成本对比**:
- 直接部署: ~2,100,000 gas
- ERC1167 Clone: ~48,000 gas
- **节省**: ~97.7%

**适用场景**:
- ✅ 需要部署大量相同逻辑的合约
- ✅ 用户自主部署 (工厂模式)
- ❌ 单个合约部署 (直接 new 更简单)

### 2. 为什么 TokenV2 必须使用 Initializable?

**原因**:
- Clone 部署时不会调用 `constructor`
- `constructor` 只在实现合约部署时执行一次
- 每个 Clone 需要独立初始化自己的状态

**解决方案**:
```solidity
// ❌ 错误: 使用 constructor
contract TokenV2 is ERC20 {
    constructor(...) ERC20(...) {
        // Clone 不会执行这里!
    }
}

// ✅ 正确: 使用 initialize
contract TokenV2 is Initializable, ERC20Upgradeable {
    constructor() {
        _disableInitializers();  // 防止实现合约被初始化
    }
    
    function initialize(...) external initializer {
        __ERC20_init(...);  // 每个 Clone 独立初始化
    }
}
```

### 3. 如何防止重入攻击?

**Checks-Effects-Interactions 模式**:
```solidity
function withdrawFees() external onlyOwner {
    // 1. Checks: 检查条件
    uint256 amount = totalFees;
    if (amount == 0) revert InvalidParameters();
    
    // 2. Effects: 修改状态 (先清零!)
    totalFees = 0;
    
    // 3. Interactions: 外部调用
    (bool success, ) = owner().call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

## 📝 License

MIT

## 🙏 致谢

- [OpenZeppelin](https://www.openzeppelin.com/) - 可升级合约库和 Clones 实现
- [Foundry](https://getfoundry.sh/) - 智能合约开发框架
- [ERC1167](https://eips.ethereum.org/EIPS/eip-1167) - 最小代理标准
