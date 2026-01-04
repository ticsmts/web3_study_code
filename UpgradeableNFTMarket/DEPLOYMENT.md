# UUPS 代理部署与升级详解

## 📦 部署架构概览

### ERC1967 代理模式

所有可升级合约（ZZToken, ZZNFT, NFTMarket）都采用相同的 **ERC1967 代理模式**：

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

### 1. NFTMarket 部署步骤

#### 第一步：部署 V1 实现合约

```solidity
// 部署 NFTMarketV1 实现
NFTMarketV1 marketImpl = new NFTMarketV1();
// 地址: 0x9f8686257748ce1723de453e28c1541681b4eaef (Sepolia)
```

**实现合约特点**:
- 包含所有业务逻辑
- 构造函数调用 `_disableInitializers()` 防止直接初始化
- 不存储任何状态数据

#### 第二步：部署 ERC1967Proxy 代理合约

```solidity
// 准备初始化数据
bytes memory initData = abi.encodeWithSelector(
    NFTMarketV1.initialize.selector  // 调用 initialize() 函数
);

// 部署代理，传入实现地址和初始化数据
ERC1967Proxy marketProxy = new ERC1967Proxy(
    address(marketImpl),  // 实现合约地址
    initData              // 初始化调用数据
);
// 代理地址: 0x3241c027b1072a79dbe9c79966098077aeabc002 (Sepolia)
```

**代理合约做了什么**:
1. 将实现地址存储在特定的存储槽 (`ERC1967` 标准)
2. 立即通过 `delegatecall` 调用实现合约的 `initialize()` 函数
3. 所有后续调用都会 `delegatecall` 到实现合约

#### 第三步：用户交互

```solidity
// 用户调用代理地址
NFTMarketV1 market = NFTMarketV1(address(marketProxy));
market.list(...);  // 实际执行的是 marketImpl 的逻辑
```

**执行流程**:
```
用户 → marketProxy.list()
       ↓ delegatecall
       marketImpl.list() (在 proxy 的上下文中执行)
       ↓
       状态保存在 marketProxy 的存储中
```

---

### 2. 升级到 V2

#### 第一步：部署 V2 实现合约

```solidity
// 部署 NFTMarketV2 实现
NFTMarketV2 marketV2Impl = new NFTMarketV2();
// 地址: 0x2fe6ce444dc3cf4b0406156e2550ee8559855a73 (Sepolia)
```

**V2 新增功能**:
- 继承 V1 的所有功能
- 新增 `EIP712Upgradeable` 支持
- 新增 `listWithSignature()` 函数
- 新增 `initializeV2()` reinitializer

#### 第二步：调用 upgradeToAndCall

```solidity
// 准备 V2 初始化数据
bytes memory v2InitData = abi.encodeWithSelector(
    NFTMarketV2.initializeV2.selector  // 初始化 EIP-712 域
);

// 升级代理到 V2
UUPSUpgradeable(marketProxy).upgradeToAndCall(
    address(marketV2Impl),  // 新实现地址
    v2InitData              // V2 初始化数据
);
```

**升级过程**:
1. `_authorizeUpgrade()` 检查权限（仅 owner）
2. 更新实现地址存储槽指向 V2
3. 调用 `initializeV2()` 初始化新功能
4. 所有旧数据保持不变

#### 第三步：验证升级

```solidity
// 代理地址不变
address proxy = 0x3241c027b1072a79dbe9c79966098077aeabc002;

// 但现在调用的是 V2 逻辑
NFTMarketV2 market = NFTMarketV2(proxy);
market.version();  // 返回 "2.0.0"
market.listWithSignature(...);  // V2 新功能可用
```

---

### 3. ZZToken 和 ZZNFT 部署

**完全相同的流程**:

#### ZZToken 部署

```solidity
// 1. 部署实现
ZZTokenUpgradeable tokenImpl = new ZZTokenUpgradeable();

// 2. 准备初始化数据
bytes memory initData = abi.encodeWithSelector(
    ZZTokenUpgradeable.initialize.selector,
    "ZZ Token",           // name
    "ZZT",                // symbol
    100_000_000 ether     // initialSupply
);

// 3. 部署代理
ERC1967Proxy tokenProxy = new ERC1967Proxy(
    address(tokenImpl),
    initData
);
```

**Sepolia 地址**:
- 实现: `0x43623fa5f52ba6c7fae160942bc7b55a1ed29056`
- 代理: `0xddb24aaa31476a0886a1d5e4bc67371271f9e3ba`

#### ZZNFT 部署

```solidity
// 1. 部署实现
ZZNFTUpgradeable nftImpl = new ZZNFTUpgradeable();

// 2. 准备初始化数据
bytes memory initData = abi.encodeWithSelector(
    ZZNFTUpgradeable.initialize.selector,
    "ZZ NFT Collection",              // name
    "ZZNFT",                           // symbol
    "https://api.example.com/nft/"    // baseURI
);

// 3. 部署代理
ERC1967Proxy nftProxy = new ERC1967Proxy(
    address(nftImpl),
    initData
);
```

**Sepolia 地址**:
- 实现: `0xe7fdfcfda714b10420c57f9cb848c321e8d6d191`
- 代理: `0x0e13e82fed033e04b8e5ae4e2856c73dc02960d0`

---

## 🔄 升级 ZZToken 和 ZZNFT

### 升级方式与 NFTMarket 完全相同

假设要升级 ZZToken 到 V2:

```solidity
// 1. 部署新实现
ZZTokenV2 tokenV2Impl = new ZZTokenV2();

// 2. 准备初始化数据（如果 V2 有新功能需要初始化）
bytes memory initData = abi.encodeWithSelector(
    ZZTokenV2.initializeV2.selector
);

// 3. 升级
UUPSUpgradeable(tokenProxy).upgradeToAndCall(
    address(tokenV2Impl),
    initData
);
```

**关键点**:
- 代理地址永不改变
- 所有余额、授权等状态保持不变
- 仅逻辑升级

---

## 🌐 Sepolia 测试网部署

### 部署记录

1. **2026-01-03 22:14** - V1 部署
   - 10 笔交易
   - Gas: 4,783,696
   - 所有合约验证完成

2. **2026-01-03 22:16** - V2 升级
   - 2 笔交易
   - Gas: 1,946,435
   - V2 实现验证完成

### 合约地址汇总

| 合约 | 类型 | 地址 | Etherscan |
|------|------|------|-----------|
| ZZToken | 实现 | `0x43623fa5f52ba6c7fae160942bc7b55a1ed29056` | [查看](https://sepolia.etherscan.io/address/0x43623fa5f52ba6c7fae160942bc7b55a1ed29056) |
| ZZToken | 代理 | `0xddb24aaa31476a0886a1d5e4bc67371271f9e3ba` | [查看](https://sepolia.etherscan.io/address/0xddb24aaa31476a0886a1d5e4bc67371271f9e3ba) |
| ZZNFT | 实现 | `0xe7fdfcfda714b10420c57f9cb848c321e8d6d191` | [查看](https://sepolia.etherscan.io/address/0xe7fdfcfda714b10420c57f9cb848c321e8d6d191) |
| ZZNFT | 代理 | `0x0e13e82fed033e04b8e5ae4e2856c73dc02960d0` | [查看](https://sepolia.etherscan.io/address/0x0e13e82fed033e04b8e5ae4e2856c73dc02960d0) |
| NFTMarketV1 | 实现 | `0x9f8686257748ce1723de453e28c1541681b4eaef` | [查看](https://sepolia.etherscan.io/address/0x9f8686257748ce1723de453e28c1541681b4eaef) |
| NFTMarketV2 | 实现 | `0x2fe6ce444dc3cf4b0406156e2550ee8559855a73` | [查看](https://sepolia.etherscan.io/address/0x2fe6ce444dc3cf4b0406156e2550ee8559855a73) |
| NFTMarket | 代理 | `0x3241c027b1072a79dbe9c79966098077aeabc002` | [查看](https://sepolia.etherscan.io/address/0x3241c027b1072a79dbe9c79966098077aeabc002) |

---

## 🎨 前端配置 (Sepolia)

### 1. 更新合约地址

`frontend/src/contracts/index.ts`:

```typescript
export const CONTRACT_ADDRESSES = {
    TOKEN: '0xddb24aaa31476a0886a1d5e4bc67371271f9e3ba' as `0x${string}`,
    NFT: '0x0e13e82fed033e04b8e5ae4e2856c73dc02960d0' as `0x${string}`,
    MARKET: '0x3241c027b1072a79dbe9c79966098077aeabc002' as `0x${string}`,
};
```

### 2. 更新网络配置

`frontend/src/components/Providers.tsx`:

```typescript
import { sepolia } from 'viem/chains';

const config = getDefaultConfig({
    appName: 'Upgradeable NFT Market',
    projectId: 'YOUR_PROJECT_ID',
    chains: [sepolia],  // 使用 Sepolia (Chain ID: 11155111)
    ssr: true,
});
```

### 3. 更新 EIP-712 chainId

`frontend/src/app/page.tsx` - `handleSignListing` 函数:

```typescript
signTypedData({
    domain: { 
        name: 'NFTMarketV2', 
        version: '1', 
        chainId: 11155111,  // Sepolia Chain ID
        verifyingContract: CONTRACT_ADDRESSES.MARKET 
    },
    // ...
});
```

### 4. 使用步骤

1. **刷新浏览器** - http://localhost:3000
2. **连接钱包** - MetaMask 会提示切换到 Sepolia
3. **获取测试 ETH** - [Sepolia 水龙头](https://sepoliafaucet.com/)
4. **开始使用** - 铸造、上架、购买 NFT

### 5. 切换回本地网络

如需切换回 Anvil 本地网络:

1. 在 `contracts/index.ts` 中恢复本地地址
2. 在 `Providers.tsx` 中使用 `anvilLocal` 配置
3. 在 `page.tsx` 中将 chainId 改回 `31337`

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

---

## 📋 部署检查清单

### V1 部署验证

- [ ] 实现合约已部署
- [ ] 代理合约已部署
- [ ] `initialize()` 已成功调用
- [ ] 代理指向正确的实现地址
- [ ] owner 地址正确
- [ ] 合约在 Etherscan 验证

### V2 升级验证

- [ ] V2 实现合约已部署
- [ ] `upgradeToAndCall()` 成功执行
- [ ] `initializeV2()` 已调用
- [ ] `version()` 返回 "2.0.0"
- [ ] V1 数据完整保留
- [ ] V2 新功能可用
- [ ] V2 实现在 Etherscan 验证

---

## 🛡️ 安全考虑

### 1. 初始化保护

```solidity
constructor() {
    _disableInitializers();  // 防止实现合约被直接初始化
}

function initialize() public initializer {
    // 仅代理可调用，且仅一次
}
```

### 2. 升级权限

```solidity
function _authorizeUpgrade(address newImplementation) 
    internal override onlyOwner 
{
    // 仅 owner 可升级
}
```

### 3. 存储布局

```solidity
// V1
contract NFTMarketV1 {
    uint256 public nextListingId;
    mapping(uint256 => Listing) public listings;
    uint256[48] private __gap;  // 预留槽位
}

// V2 - 只能在 __gap 之后添加新变量
contract NFTMarketV2 is NFTMarketV1 {
    mapping(address => uint256) public sellerNonces;  // 新变量
    mapping(uint256 => bool) public isSignatureListing;
}
```

**规则**:
- ❌ 不能改变现有变量顺序
- ❌ 不能改变现有变量类型
- ✅ 可以在末尾添加新变量
- ✅ 使用 `__gap` 预留空间

---

## 🔧 故障排查

### 问题：升级后调用失败

**原因**: 可能是存储布局冲突

**解决**: 
1. 检查 V2 是否正确继承 V1
2. 确认没有修改现有变量
3. 使用 `forge inspect` 检查存储布局

### 问题：initialize 调用失败

**原因**: 可能已经初始化过

**解决**:
1. 检查 `initializer` 修饰符
2. V2 使用 `reinitializer(2)` 而非 `initializer`
3. 确认实现合约构造函数调用了 `_disableInitializers()`

### 问题：MetaMask 签名不弹窗

**原因**: EIP-712 chainId 不匹配

**解决**:
1. Sepolia 使用 chainId `11155111`
2. Anvil 使用 chainId `31337`
3. 确保前端配置与当前网络一致
