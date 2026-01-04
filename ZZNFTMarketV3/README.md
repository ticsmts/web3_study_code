# ZZNFTMarketV3 - NFT 市场合约（EIP-712 白名单许可购买）

基于 EIP-712 签名的 NFT 市场合约，支持项目方离线签名授权白名单用户购买 NFT。

## 📋 目录

- [项目概述](#项目概述)
- [核心功能](#核心功能)
- [技术架构](#技术架构)
- [合约实现详解](#合约实现详解)
- [部署指南](#部署指南)
- [Gas 优化](#gas-优化)
- [测试](#测试)
- [前端集成](#前端集成)

---

## 项目概述

ZZNFTMarketV3 是一个支持白名单许可购买的 NFT 市场合约。项目方可以通过离线签名的方式为特定用户授权购买权限，用户持有签名后即可调用 `permitBuy()` 完成购买。

### 核心特性

- 🎨 **NFT 上架**：卖家可自定义价格上架 NFT
- 🔐 **白名单许可**：项目方离线签名授权买家
- ✅ **签名验证**：基于 EIP-712 的类型化数据签名
- 🛡️ **重放保护**：Nonce 机制防止签名重放攻击
- ⚡ **Gas 优化**：经过深度优化，部署成本降低 51.4%

---

## 核心功能

### 1. NFT 上架 (list)

卖家将 NFT 托管到合约并设置价格。

```solidity
function list(
    address nft,
    uint256 tokenId,
    address payToken,
    uint256 price
) external nonReentrant returns (uint256 listingId)
```

**流程**：
1. 验证价格非零
2. 验证调用者是 NFT 所有者
3. 将 NFT 转移到合约托管
4. 创建 Listing 记录
5. 返回 listingId

### 2. 普通购买 (buyNFT)

任何人都可以购买已上架的 NFT（无白名单限制）。

```solidity
function buyNFT(
    uint256 listingId,
    uint256 payAmount
) external nonReentrant
```

**流程**：
1. 验证 listing 处于活跃状态
2. 验证买家不是卖家本人
3. 验证支付金额正确
4. 将 listing 标记为不活跃
5. 转移 ERC20 代币给卖家
6. 转移 NFT 给买家

### 3. 白名单许可购买 (permitBuy) ⭐

**核心功能**：买家需要持有项目方的 EIP-712 签名才能购买。

```solidity
function permitBuy(
    uint256 listingId,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external nonReentrant
```

**流程**：
1. 检查签名是否过期 (`block.timestamp > deadline`)
2. 验证 listing 处于活跃状态
3. 获取买家当前 nonce 并递增（防重放）
4. 构造 EIP-712 签名消息哈希
5. 恢复签名者地址
6. 验证签名者是否为项目方 signer
7. 执行购买（转移代币和 NFT）

---

## 技术架构

### 项目结构

```
ZZNFTMarketV3/
├── src/
│   ├── ZZNFTMarketV3.sol      # 市场合约（核心）
│   ├── ZZNFT.sol               # ERC721 NFT 合约
│   ├── ZZToken.sol             # ERC20 代币合约
│   └── interfaces/
│       └── IERC20Permit.sol    # ERC20 Permit 接口
├── test/
│   └── ZZNFTMarketV3.t.sol     # 完整测试套件（14个测试）
├── script/
│   └── Deploy.s.sol            # 部署脚本
├── frontend/                    # Next.js 前端
│   ├── src/
│   │   ├── components/         # React 组件
│   │   ├── config/             # 合约配置
│   │   └── utils/              # 工具函数
│   └── package.json
├── gas_report_v1.md            # 优化前 Gas 报告
├── gas_report_v2.md            # 优化后 Gas 报告
└── foundry.toml                # Foundry 配置
```

### 技术栈

| 层级 | 技术 |
|------|------|
| **智能合约** | Solidity 0.8.30, Foundry |
| **前端框架** | Next.js 16, React 19 |
| **Web3 库** | Wagmi v2, Viem v2, RainbowKit |
| **标准协议** | ERC721, ERC20, EIP-712 |

---

## 合约实现详解

### EIP-712 签名机制

#### 1. Domain Separator

```solidity
constructor(address _signer) EIP712("ZZNFTMarketV3", "1") {
    signer = _signer;
    admin = msg.sender;
}
```

EIP-712 Domain 包含：
- `name`: "ZZNFTMarketV3"
- `version`: "1"
- `chainId`: 自动获取
- `verifyingContract`: 合约地址

#### 2. 类型化数据哈希

```solidity
bytes32 public constant WHITELIST_PERMIT_TYPEHASH = keccak256(
    "WhitelistPermit(address buyer,uint256 listingId,uint256 nonce,uint256 deadline)"
);
```

#### 3. 签名验证流程

```solidity
// 构造结构体哈希
bytes32 structHash = keccak256(
    abi.encode(
        WHITELIST_PERMIT_TYPEHASH,
        msg.sender,      // buyer
        listingId,
        currentNonce,
        deadline
    )
);

// 生成 EIP-712 消息哈希
bytes32 hash = _hashTypedDataV4(structHash);

// 恢复签名者
address recoveredSigner = ECDSA.recover(hash, v, r, s);

// 验证签名者
if (recoveredSigner != signer) revert NotWhitelisted();
```

### 存储优化

#### Listing 结构体打包

**优化前**（6 个存储槽）：
```solidity
struct Listing {
    address seller;     // slot 0
    address nft;        // slot 1
    uint256 tokenId;    // slot 2
    address payToken;   // slot 3
    uint256 price;      // slot 4
    bool active;        // slot 5
}
```

**优化后**（5 个存储槽）：
```solidity
struct Listing {
    address seller;     // slot 0: 20 bytes
    bool active;        // slot 0: 1 byte (packed)
    address nft;        // slot 1
    uint256 tokenId;    // slot 2
    address payToken;   // slot 3
    uint256 price;      // slot 4
}
```

**节省**：每次创建 listing 节省 ~2100 gas（1 个 SSTORE）

### 安全机制

#### 1. 重入保护

```solidity
uint256 private constant _NOT_ENTERED = 1;
uint256 private constant _ENTERED = 2;
uint256 private _locked = _NOT_ENTERED;

modifier nonReentrant() {
    require(_locked == _NOT_ENTERED, "REENTRANCY");
    _locked = _ENTERED;
    _;
    _locked = _NOT_ENTERED;
}
```

#### 2. Nonce 防重放

```solidity
mapping(address => uint256) public nonces;

// 在 permitBuy 中
uint256 currentNonce = nonces[msg.sender];
unchecked {
    nonces[msg.sender] = currentNonce + 1;
}
```

每个用户维护独立的 nonce，签名使用后立即失效。

#### 3. 自定义错误

使用 custom errors 替代 `require` 字符串，节省 gas：

```solidity
error InvalidPrice();
error NotOwner();
error ListingNotActive();
error BuySelf();
error WrongPayment();
error TransferFailed();
error ExpiredDeadline();
error NotWhitelisted();
```

---

## 部署指南

### 前置要求

- Foundry
- Node.js 18+
- Anvil (本地测试网)

### 1. 安装依赖

```bash
# 安装 Foundry 依赖
forge install

# 安装前端依赖
cd frontend && npm install
```

### 2. 本地部署

#### 启动 Anvil

```bash
anvil
```

默认账户：
- Account #0: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` (Deployer/Signer)
- Account #1: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` (Buyer)

#### 部署合约

```bash
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

部署脚本会：
1. 部署 `ZZTOKEN` (ERC20)
2. 部署 `ZZNFT` (ERC721)
3. 部署 `ZZNFTMarketV3`（deployer 作为 signer）
4. 铸造 3 个测试 NFT (tokenId: 1, 2, 3)
5. 转移 10000 ZZ 代币给 buyer

#### 输出示例

```
========== Deployment Summary ==========
TOKEN_ADDRESS:  0x5FbDB2315678afecb367f032d93F642f64180aa3
NFT_ADDRESS:    0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
MARKET_ADDRESS: 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
=========================================
```

### 3. 测试网部署

```bash
# 设置环境变量
export PRIVATE_KEY=<your_private_key>
export RPC_URL=<sepolia_rpc_url>

# 部署
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

---

## Gas 优化

### 优化成果对比

| 指标 | 优化前 (v1) | 优化后 (v2) | 节省 |
|------|-------------|-------------|------|
| **部署成本** | 2,364,642 gas | 1,149,261 gas | **-51.4%** |
| **合约大小** | 12,666 bytes | 5,951 bytes | **-53.0%** |
| **list()** | 232,298 gas | 205,704 gas | **-11.5%** |
| **permitBuy()** | 146,750 gas | 142,725 gas | **-2.7%** |

### 优化技术详解

#### 1. 结构体打包 (Struct Packing)

将 `bool active` 与 `address seller` 打包到同一存储槽。

**原理**：
- `address` 占 20 bytes
- `bool` 占 1 byte
- 一个存储槽 32 bytes，可以同时存储两者

**收益**：每次 `list()` 节省 ~2100 gas

#### 2. Unchecked 算术

```solidity
// 优化前
listingId = nextListingId++;

// 优化后
listingId = nextListingId;
unchecked {
    nextListingId = listingId + 1;
}
```

**原理**：Solidity 0.8+ 默认开启溢出检查，但 `nextListingId` 不可能溢出（uint256 最大值），使用 `unchecked` 跳过检查。

**收益**：每次调用节省 ~20-40 gas

#### 3. 存储变量缓存

```solidity
// 优化前
IERC20Like(L.payToken).transferFrom(msg.sender, L.seller, L.price);
IZZNFT(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);

// 优化后
address seller_ = L.seller;
address nft_ = L.nft;
uint256 tokenId_ = L.tokenId;
address payToken_ = L.payToken;
uint256 price_ = L.price;

IERC20Like(payToken_).transferFrom(msg.sender, seller_, price_);
IZZNFT(nft_).safeTransferFrom(address(this), msg.sender, tokenId_);
```

**原理**：每次读取存储变量（SLOAD）消耗 ~100 gas，缓存到内存（MLOAD）只需 ~3 gas。

**收益**：每避免一次 SLOAD 节省 ~100 gas

#### 4. IR 编译器优化

```toml
# foundry.toml
via_ir = true
optimizer = true
optimizer_runs = 200
```

**原理**：
- `via_ir`: 使用 Yul IR 中间表示，进行更深层次的优化
- `optimizer_runs`: 200 表示优化部署成本和运行成本的平衡点

**收益**：整体优化 ~30-50%

### 完整 Gas 报告

详见：
- [gas_report_v1.md](./gas_report_v1.md) - 优化前
- [gas_report_v2.md](./gas_report_v2.md) - 优化后

---

## 测试

### 运行测试

```bash
# 运行所有测试
forge test

# 详细输出
forge test -vvv

# Gas 报告
forge test --gas-report

# 单个测试
forge test --match-test test_PermitBuy_Success -vvv
```

### 测试覆盖

测试套件包含 14 个测试用例：

#### 上架功能测试
- ✅ `test_List_Success_EmitsEvent` - 成功上架并触发事件
- ✅ `test_List_Fail_ZeroPrice` - 价格为 0 失败
- ✅ `test_List_Fail_NotOwner` - 非所有者上架失败

#### 普通购买测试
- ✅ `test_BuyNFT_Success` - 成功购买
- ✅ `test_BuyNFT_Fail_BuySelf` - 自己购买自己的 NFT 失败

#### 白名单许可购买测试
- ✅ `test_PermitBuy_Success` - 成功使用签名购买
- ✅ `test_PermitBuy_Fail_InvalidSignature` - 无效签名失败
- ✅ `test_PermitBuy_Fail_ExpiredDeadline` - 签名过期失败
- ✅ `test_PermitBuy_Fail_WrongBuyer` - 签名给其他人失败
- ✅ `test_PermitBuy_Fail_WrongListingId` - 签名用于错误的 listing 失败
- ✅ `test_PermitBuy_Fail_ReplayAttack` - 重放攻击失败

#### 管理功能测试
- ✅ `test_SetSigner_Success` - 管理员更新 signer
- ✅ `test_SetSigner_Fail_NotAdmin` - 非管理员更新失败

#### 模糊测试
- ✅ `testFuzz_PermitBuy_RandomPriceAndDeadline` - 随机价格和过期时间测试

---

## 前端集成

### 启动前端

```bash
cd frontend
npm run dev
```

访问：http://localhost:3000

### 核心功能

#### 1. 连接钱包

使用 RainbowKit：

```typescript
import { ConnectButton } from '@rainbow-me/rainbowkit';

<ConnectButton />
```

#### 2. 上架 NFT

```typescript
// 1. 授权 NFT
const { writeContract } = useWriteContract();
await writeContract({
  address: NFT_ADDRESS,
  abi: ZZNFT_ABI,
  functionName: 'approve',
  args: [MARKET_ADDRESS, tokenId],
});

// 2. 上架
await writeContract({
  address: MARKET_ADDRESS,
  abi: MARKET_ABI,
  functionName: 'list',
  args: [NFT_ADDRESS, tokenId, TOKEN_ADDRESS, price],
});
```

#### 3. 生成白名单签名（项目方）

```typescript
import { signTypedData } from '@wagmi/core';

const domain = {
  name: 'ZZNFTMarketV3',
  version: '1',
  chainId: 31337,
  verifyingContract: MARKET_ADDRESS,
};

const types = {
  WhitelistPermit: [
    { name: 'buyer', type: 'address' },
    { name: 'listingId', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
};

const signature = await signTypedData({
  domain,
  types,
  primaryType: 'WhitelistPermit',
  message: {
    buyer: buyerAddress,
    listingId: BigInt(listingId),
    nonce: BigInt(nonce),
    deadline: BigInt(deadline),
  },
});

// 分离 v, r, s
const { v, r, s } = splitSignature(signature);
```

#### 4. 白名单购买

```typescript
// 1. 授权代币
await writeContract({
  address: TOKEN_ADDRESS,
  abi: TOKEN_ABI,
  functionName: 'approve',
  args: [MARKET_ADDRESS, price],
});

// 2. 使用签名购买
await writeContract({
  address: MARKET_ADDRESS,
  abi: MARKET_ABI,
  functionName: 'permitBuy',
  args: [listingId, deadline, v, r, s],
});
```

### 前端截图

| 步骤 | 截图 |
|------|------|
| NFT 授权 | ![NFT授权](images/image.png) |
| NFT 上架 | ![NFT上架](images/image-1.png) |
| 设置白名单 | ![设置buyer白名单](images/image-2.png) |
| 生成签名 | ![生成白名单](images/image-3.png) |
| 授权代币 | ![授权代币](images/image-4.png) |
| 购买 NFT | ![购买NFT](images/image-5.png) |

---

## 重难点知识总结

### 1. EIP-712 签名机制

**核心概念**：
- 类型化数据签名，比普通签名更安全、更易读
- 包含 Domain Separator 防止跨链/跨合约重放
- MetaMask 会展示结构化数据供用户确认

**实现要点**：
- 继承 OpenZeppelin 的 `EIP712` 合约
- 定义 `TYPEHASH` 常量
- 使用 `_hashTypedDataV4()` 生成最终哈希
- 使用 `ECDSA.recover()` 恢复签名者

### 2. 存储槽优化

**核心原则**：
- 一个存储槽 32 bytes
- 相邻的小类型变量会自动打包
- 读写存储（SLOAD/SSTORE）是最昂贵的操作

**优化技巧**：
- 将 `bool`、`uint8`、`address` 等小类型放在一起
- 缓存频繁读取的存储变量到内存
- 使用 `immutable` 和 `constant`

### 3. 重入攻击防护

**攻击原理**：
- 外部调用可能回调当前合约
- 状态未更新前被重复调用

**防护方案**：
- 使用 `nonReentrant` 修饰符
- 遵循 Checks-Effects-Interactions 模式
- 先更新状态，再进行外部调用

### 4. Nonce 防重放

**重放攻击**：
- 攻击者重复使用同一个签名
- 可能导致资金损失

**防护方案**：
- 每个用户维护独立的 nonce
- 签名验证前递增 nonce
- 签名只能使用一次

### 5. Gas 优化策略

**优化层级**：
1. **算法层**：减少存储读写、优化循环
2. **编码层**：使用 `unchecked`、custom errors
3. **编译层**：启用 optimizer、via_ir

**关键指标**：
- SLOAD: ~100 gas
- SSTORE (新值): ~20000 gas
- SSTORE (修改): ~5000 gas
- MLOAD/MSTORE: ~3 gas

---

## 常见问题

### Q1: 为什么需要白名单许可购买？

**A**: 适用于以下场景：
- NFT 白名单销售（只允许特定用户购买）
- 限时优惠（签名可设置过期时间）
- 防止机器人抢购
- 项目方可控的销售策略

### Q2: EIP-712 签名和普通签名有什么区别？

**A**: 
- **普通签名**：签名任意数据，用户看到的是哈希值
- **EIP-712**：签名结构化数据，钱包会展示可读内容，更安全

### Q3: 如何防止签名被重复使用？

**A**: 
- 使用 nonce 机制，每个签名只能用一次
- 设置 deadline，签名过期后无效
- 签名绑定特定的 buyer 和 listingId

### Q4: Gas 优化会影响合约安全性吗？

**A**: 
- 不会，优化只是改变实现方式
- 所有测试用例依然通过
- 核心逻辑和安全机制保持不变

---

## 参考资料

- [EIP-712 规范](https://eips.ethereum.org/EIPS/eip-712)
- [OpenZeppelin EIP712 实现](https://docs.openzeppelin.com/contracts/4.x/api/utils#EIP712)
- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Gas 优化技巧](https://github.com/iskdrews/awesome-solidity-gas-optimization)

---

## License

MIT
