# UUPS 代理部署与升级详解

## 📦 部署架构概览

### ERC1967 代理模式

工厂合约采用 **ERC1967 代理模式**，支持无缝升级：

```
用户调用
   ↓
ERC1967Proxy (固定地址，存储数据)
   ↓ delegatecall
Implementation (可升级，包含逻辑)
```

**关键特性**:
- 代理地址永不改变
- 所有状态存储在代理合约
- 实现合约可以升级
- 用户始终与代理交互

---

## 🚀 详细部署流程

### 1. V1 部署步骤

#### 第一步：部署 V1 实现合约

```solidity
// 部署 InscriptionFactoryV1 实现
InscriptionFactoryV1 factoryImpl = new InscriptionFactoryV1();
// 地址: 0xcea66d15f6800Ea380D09a649dAA02E6B5ec963c (Sepolia)
```

**实现合约特点**:
- 包含所有业务逻辑
- 构造函数调用 `_disableInitializers()` 防止直接初始化
- 不存储任何状态数据

#### 第二步：部署 ERC1967Proxy 代理合约

```solidity
// 准备初始化数据
bytes memory initData = abi.encodeWithSelector(
    InscriptionFactoryV1.initialize.selector,
    msg.sender  // initialOwner
);

// 部署代理，传入实现地址和初始化数据
ERC1967Proxy factoryProxy = new ERC1967Proxy(
    address(factoryImpl),  // 实现合约地址
    initData               // 初始化调用数据
);
// 代理地址: 0x50180de3322F3309Db32f19D5537C3698EEE9078 (Sepolia)
```

**代理合约做了什么**:
1. 将实现地址存储在特定的存储槽 (`ERC1967` 标准)
2. 立即通过 `delegatecall` 调用实现合约的 `initialize()` 函数
3. 所有后续调用都会 `delegatecall` 到实现合约

#### 第三步：用户交互

```solidity
// 用户调用代理地址
InscriptionFactoryV1 factory = InscriptionFactoryV1(address(factoryProxy));
factory.deployInscription(...);  // 实际执行的是 factoryImpl 的逻辑
```

**执行流程**:
```
用户 → factoryProxy.deployInscription()
       ↓ delegatecall
       factoryImpl.deployInscription() (在 proxy 的上下文中执行)
       ↓
       状态保存在 factoryProxy 的存储中
```

---

### 2. 升级到 V2

#### 第一步：部署 V2 实现合约

```solidity
// 1. 部署 InscriptionFactoryV2 实现
InscriptionFactoryV2 factoryV2Impl = new InscriptionFactoryV2();
// 地址: 0x2227B9300ED19eAdFF91DBd7f536dD45D1A84e6f (Sepolia)

// 2. 部署 InscriptionTokenV2 实现 (用于 Clone)
InscriptionTokenV2 tokenV2Impl = new InscriptionTokenV2();
// 地址: 0x5C86ccaebE69f50DC23c4c44d66597D39ed9ab55 (Sepolia)
```

**V2 新增功能**:
- 继承 V1 的所有功能
- 新增 ERC1167 Clones 支持
- 新增付费铸造机制
- 新增 `withdrawFees()` 函数
- 新增 `initializeV2()` reinitializer

#### 第二步：调用 upgradeToAndCall

```solidity
// 准备 V2 初始化数据
bytes memory v2InitData = abi.encodeWithSelector(
    InscriptionFactoryV2.initializeV2.selector,
    address(tokenV2Impl)  // TokenV2 实现合约地址
);

// 升级代理到 V2
UUPSUpgradeable(factoryProxy).upgradeToAndCall(
    address(factoryV2Impl),  // 新实现地址
    v2InitData               // V2 初始化数据
);
```

**升级过程**:
1. `_authorizeUpgrade()` 检查权限（仅 owner）
2. 更新实现地址存储槽指向 V2
3. 调用 `initializeV2(tokenV2Impl)` 初始化新功能
4. 所有旧数据保持不变

#### 第三步：验证升级

```solidity
// 代理地址不变
address proxy = 0x50180de3322F3309Db32f19D5537C3698EEE9078;

// 但现在调用的是 V2 逻辑
InscriptionFactoryV2 factory = InscriptionFactoryV2(proxy);
factory.version();  // 返回 "2.0.0"
factory.deployInscription(symbol, supply, perMint, price);  // V2 新功能可用
```

---

## 🔄 ERC1167 Clone 部署流程

### V2 部署铭文的详细步骤

```solidity
// 用户调用
factory.deployInscription("INSC", 1000000, 100, 0.01 ether);
    ↓
// 1. 克隆 TokenV2 实现合约
address clone = tokenImplementation.clone();
// 部署 45 字节的代理合约
    ↓
// 2. 初始化克隆合约
InscriptionTokenV2(clone).initialize(
    "INSC",          // name
    "INSC",          // symbol
    1000000,         // maxSupply
    100,             // perMint
    address(this)    // factory
);
// 在 clone 的存储中设置状态变量
    ↓
// 3. 记录铭文信息
inscriptions[clone] = InscriptionInfo(...);
inscriptionsV2[clone] = InscriptionInfoV2(price: 0.01 ether, isV2: true);
    ↓
// 4. 返回 clone 地址
return clone;
```

**Clone 合约字节码**:
```
363d3d373d3d3d363d73[TokenV2实现地址]5af43d82803e903d91602b57fd5bf3
```

**执行流程**:
```
用户调用 clone.mint(user)
    ↓
Clone 合约 (45 bytes)
    ↓ delegatecall
TokenV2 实现合约
    ↓ 在 Clone 的存储上下文中执行
    ↓
修改 Clone 的存储 (totalMinted, balances)
    ↓
返回结果
```

---

## 🌐 Sepolia 测试网部署

### 部署记录

**V1 部署** (2024-12-XX):
- 交易数: 3 笔
- Gas 消耗: ~1,500,000
- 合约验证: 完成

**V2 升级** (2024-12-XX):
- 交易数: 3 笔
- Gas 消耗: ~800,000
- 合约验证: 完成

### 合约地址汇总

| 合约 | 类型 | 地址 | Etherscan |
|------|------|------|-----------| | InscriptionFactory | 代理 | `0x50180de3322F3309Db32f19D5537C3698EEE9078` | [查看](https://sepolia.etherscan.io/address/0x50180de3322F3309Db32f19D5537C3698EEE9078) |
| InscriptionFactoryV1 | 实现 | `0xcea66d15f6800Ea380D09a649dAA02E6B5ec963c` | [查看](https://sepolia.etherscan.io/address/0xcea66d15f6800Ea380D09a649dAA02E6B5ec963c) |
| InscriptionFactoryV2 | 实现 | `0x2227B9300ED19eAdFF91DBd7f536dD45D1A84e6f` | [查看](https://sepolia.etherscan.io/address/0x2227b9300ed19eadff91dbd7f536dd45d1a84e6f) |
| InscriptionTokenV2 | 实现 | `0x5C86ccaebE69f50DC23c4c44d66597D39ed9ab55` | [查看](https://sepolia.etherscan.io/address/0x5C86ccaebE69f50DC23c4c44d66597D39ed9ab55) |

---

## 🎨 前端配置

### 1. 更新合约地址

`frontend/src/contract.js`:

```javascript
export const FACTORY_ADDRESS = '0x50180de3322F3309Db32f19D5537C3698EEE9078';

export const FACTORY_ABI = [
    // ... ABI 内容
];
```

### 2. 更新网络配置

```javascript
// 使用 Sepolia 测试网
const provider = new ethers.BrowserProvider(window.ethereum);

// 请求切换到 Sepolia
await window.ethereum.request({
    method: 'wallet_switchEthereumChain',
    params: [{ chainId: '0xaa36a7' }],  // Sepolia Chain ID: 11155111
});
```

### 3. 使用步骤

1. **连接钱包** - MetaMask 会提示切换到 Sepolia
2. **获取测试 ETH** - [Sepolia 水龙头](https://sepoliafaucet.com/)
3. **部署铭文** - 设置参数并部署
4. **铸造铭文** - 支付 ETH 铸造
5. **提取收益** - Owner 提取累计费用

---

## 🔐 UUPS vs Transparent Proxy

### 为什么选择 UUPS?

| 特性 | UUPS | Transparent Proxy |
|------|------|-------------------|
| 升级逻辑位置 | 实现合约 | 代理合约 |
| Gas 成本 | 更低 | 更高 |
| 代理大小 | 更小 | 更大 |
| 升级权限 | 实现合约控制 | 代理 admin 控制 |

**UUPS 优势**:
- 每次调用节省 gas（无需检查 admin）
- 代理合约更简单
- 升级逻辑可以随实现一起升级

**UUPS 注意事项**:
- 必须在实现合约中实现 `_authorizeUpgrade()`
- 升级错误可能导致合约无法再次升级
- 需要仔细测试升级逻辑

---

## 📋 部署检查清单

### V1 部署验证

- [ ] InscriptionFactoryV1 实现已部署
- [ ] ERC1967Proxy 代理已部署
- [ ] `initialize(owner)` 已成功调用
- [ ] 代理指向正确的实现地址
- [ ] owner 地址正确
- [ ] 合约在 Etherscan 验证
- [ ] `version()` 返回 "1.0.0"
- [ ] `deployInscription()` 功能正常
- [ ] `mintInscription()` 功能正常

### V2 升级验证

- [ ] InscriptionFactoryV2 实现已部署
- [ ] InscriptionTokenV2 实现已部署
- [ ] `upgradeToAndCall()` 成功执行
- [ ] `initializeV2(tokenV2Impl)` 已调用
- [ ] `version()` 返回 "2.0.0"
- [ ] V1 数据完整保留
- [ ] V1 铭文仍可正常铸造
- [ ] V2 新功能可用 (Clone 部署)
- [ ] 付费铸造功能正常
- [ ] `withdrawFees()` 功能正常
- [ ] V2 实现在 Etherscan 验证

---

## 🛡️ 安全考虑

### 1. 初始化保护

```solidity
constructor() {
    _disableInitializers();  // 防止实现合约被直接初始化
}

function initialize(address initialOwner) public initializer {
    // 仅代理可调用，且仅一次
}

function initializeV2(address _tokenImplementation) external reinitializer(2) {
    // 升级时调用，版本号递增
}
```

**为什么需要 `_disableInitializers()`?**
- 防止攻击者直接调用实现合约的 `initialize()`
- 确保只有通过代理才能初始化
- 保护实现合约不被恶意初始化

### 2. 升级权限

```solidity
function _authorizeUpgrade(address newImplementation) 
    internal override onlyOwner 
{
    // 仅 owner 可升级
}
```

**权限控制**:
- 只有 owner 可以升级合约
- 升级前应充分测试新实现
- 考虑使用多签钱包作为 owner

### 3. 存储布局

```solidity
// V1
contract InscriptionFactoryV1 {
    mapping(address => InscriptionInfo) public inscriptions;
    address[] public allInscriptions;
    uint256[48] private __gap;  // 预留槽位
}

// V2 - 只能在 __gap 之后添加新变量
contract InscriptionFactoryV2 is InscriptionFactoryV1 {
    using Clones for address;
    
    address public tokenImplementation;  // 新变量
    mapping(address => InscriptionInfoV2) public inscriptionsV2;
    uint256 public totalFees;
}
```

**存储布局规则**:
- ❌ 不能改变现有变量顺序
- ❌ 不能改变现有变量类型
- ❌ 不能删除现有变量
- ✅ 可以在末尾添加新变量
- ✅ 使用 `__gap` 预留空间

### 4. 重入攻击防护

```solidity
function withdrawFees() external onlyOwner {
    uint256 amount = totalFees;
    if (amount == 0) revert InvalidParameters();
    
    // ✅ 先修改状态
    totalFees = 0;
    
    // ✅ 再进行外部调用
    (bool success, ) = owner().call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

**Checks-Effects-Interactions 模式**:
1. **Checks**: 检查条件
2. **Effects**: 修改状态
3. **Interactions**: 外部调用

### 5. Clone 安全性

**实现合约不可变**:
- 一旦部署，所有 Clone 永久指向该实现
- 实现合约的 bug 会影响所有 Clone
- 部署前必须充分测试

**初始化保护**:
```solidity
// TokenV2 实现合约
constructor() {
    _disableInitializers();  // 防止实现合约被初始化
}

function initialize(...) external initializer {
    // 每个 Clone 独立初始化
}
```

---

## 🔧 故障排查

### 问题：升级后调用失败

**原因**: 可能是存储布局冲突

**解决**: 
1. 检查 V2 是否正确继承 V1
2. 确认没有修改现有变量
3. 使用 `forge inspect` 检查存储布局:
   ```bash
   forge inspect InscriptionFactoryV1 storage-layout
   forge inspect InscriptionFactoryV2 storage-layout
   ```

### 问题：initialize 调用失败

**原因**: 可能已经初始化过

**解决**:
1. 检查 `initializer` 修饰符
2. V2 使用 `reinitializer(2)` 而非 `initializer`
3. 确认实现合约构造函数调用了 `_disableInitializers()`

### 问题：Clone 初始化失败

**原因**: 实现合约未正确配置

**解决**:
1. 确认 TokenV2 实现合约已部署
2. 检查 `initializeV2(tokenV2Impl)` 是否成功调用
3. 验证 `tokenImplementation` 地址正确

### 问题：付费铸造失败

**原因**: 支付金额不匹配

**解决**:
1. 检查 `msg.value == price`
2. 确认前端发送了正确的 ETH 数量
3. 验证铭文的 `price` 设置正确

### 问题：提取收益失败

**原因**: 权限或余额问题

**解决**:
1. 确认调用者是 owner
2. 检查 `totalFees > 0`
3. 验证合约有足够的 ETH 余额

---

## 📊 Gas 成本分析

### V1 vs V2 部署成本

| 操作 | V1 (new) | V2 (Clone) | 节省 |
|------|----------|------------|------|
| 部署铭文 | ~2,100,000 | ~48,000 | ~97.7% |
| 铸造 (免费) | ~50,000 | ~52,600 | -5.2% |
| 铸造 (付费) | N/A | ~55,000 | - |

**结论**:
- V2 部署成本大幅降低
- 铸造成本略有增加 (delegatecall 开销)
- 适合大量部署场景

### 升级成本

| 操作 | Gas 成本 |
|------|---------|
| 部署 V2 实现 | ~1,200,000 |
| 部署 TokenV2 实现 | ~800,000 |
| upgradeToAndCall | ~50,000 |
| **总计** | **~2,050,000** |

---

## 🚀 最佳实践

### 1. 部署前

- ✅ 充分测试所有功能
- ✅ 审计智能合约代码
- ✅ 验证存储布局兼容性
- ✅ 准备升级回滚方案

### 2. 部署时

- ✅ 使用多签钱包作为 owner
- ✅ 记录所有部署地址
- ✅ 在 Etherscan 验证合约
- ✅ 测试所有核心功能

### 3. 升级时

- ✅ 在测试网先验证升级
- ✅ 通知用户即将升级
- ✅ 准备紧急暂停机制
- ✅ 升级后全面测试

### 4. 运营中

- ✅ 监控合约事件
- ✅ 定期审计安全性
- ✅ 及时响应用户反馈
- ✅ 保持代码文档更新

---

## 📚 参考资料

- [ERC1967 标准](https://eips.ethereum.org/EIPS/eip-1967)
- [ERC1167 最小代理](https://eips.ethereum.org/EIPS/eip-1167)
- [OpenZeppelin UUPS](https://docs.openzeppelin.com/contracts/4.x/api/proxy#UUPSUpgradeable)
- [OpenZeppelin Clones](https://docs.openzeppelin.com/contracts/4.x/api/proxy#Clones)
- [Foundry 文档](https://book.getfoundry.sh/)
