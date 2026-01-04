# AirdropMerkleNFTMarket

基于 Merkle 树白名单验证的 NFT 市场合约，支持 EIP-2612 Permit 授权和 Multicall 批量调用，白名单用户享受 50% 折扣。

## ✨ 功能特性

- 🌳 **Merkle 树白名单验证** - 链下生成 Merkle 树，链上验证 Proof
- 💰 **50% 折扣优惠** - 白名单用户享受上架价格的 50% 折扣
- 🔐 **EIP-2612 Permit** - Token 支持离线签名授权，无需单独 approve
- 🚀 **Multicall 批量调用** - 一次交易完成 `permitPrePay` + `claimNFT`
- 🛡️ **安全防护** - 防重入攻击、权限控制
- ✅ **完整测试** - 13 个测试用例全部通过

## 📁 项目结构

```
AirdropMerkleNFTMarket/
├── src/
│   ├── AirdropMerkleNFTMarket.sol  # 主合约 (286 行)
│   ├── ZZToken.sol                  # ERC20 + EIP-2612 Permit
│   └── ZZNFT.sol                    # ERC721 NFT
├── test/
│   └── AirdropMerkleNFTMarket.t.sol # 测试文件 (13 tests)
├── script/
│   └── Deploy.s.sol                 # 部署脚本
└── frontend/                        # Next.js 前端
    ├── app/
    │   └── page.tsx                 # 主页面
    ├── components/
    │   ├── ListNFT.tsx              # 上架 NFT
    │   ├── MerkleClaimNFT.tsx       # 白名单购买
    │   ├── WhitelistManager.tsx     # 白名单管理
    │   └── AdminTools.tsx           # 管理员工具
    ├── config/
    │   └── contracts.ts             # 合约配置
    └── utils/
        └── merkleTree.ts            # Merkle 树工具 (148 行)
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

**测试结果**: 13/13 通过 ✅

```
AirdropMerkleNFTMarketTest:
  ✅ test_List_Success
  ✅ test_ClaimNFT_WithValidProof
  ✅ test_ClaimNFT_WithInvalidProof_Reverts
  ✅ test_ClaimNFT_50PercentDiscount
  ✅ test_PermitPrePay_Success
  ✅ test_Multicall_PermitAndClaim
  ✅ test_SetMerkleRoot
  ✅ test_IsWhitelisted
  ✅ test_GetDiscountedPrice
  ... (13 tests total)
```

### 3. 本地部署

```bash
# 终端 1: 启动 Anvil 本地节点
anvil

# 终端 2: 部署合约
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

### 4. 启动前端

```bash
cd frontend
npm run dev
# 访问 http://localhost:3000
```

## 🔧 核心技术实现

### 1. Merkle 树白名单验证

#### 1.1 什么是 Merkle 树?

Merkle 树（默克尔树）是一种**哈希二叉树**，用于高效验证大量数据中的某个元素是否存在。

**核心思想**:
- 将所有白名单地址作为叶子节点
- 两两配对计算哈希，生成父节点
- 递归向上，直到得到唯一的根哈希 (Merkle Root)
- 链上只需存储根哈希，节省 gas
- 用户提供 Merkle Proof 证明自己在白名单中

**优势**:
- ✅ 链上存储成本极低 (仅一个 bytes32)
- ✅ 验证成本低 (O(log n))
- ✅ 支持大量白名单地址
- ✅ 隐私性好 (不暴露完整白名单)

#### 1.2 Merkle 树结构

**示例**: 4 个地址的 Merkle 树

```
                    Root
                   /    \
                  /      \
                 /        \
              Hash01    Hash23
              /  \      /  \
             /    \    /    \
          Leaf0 Leaf1 Leaf2 Leaf3
            |     |     |     |
          Addr0 Addr1 Addr2 Addr3
```

**计算过程**:
```
1. 叶子节点: Leaf0 = keccak256(abi.encodePacked(Addr0))
2. 父节点: Hash01 = keccak256(abi.encodePacked(Leaf0, Leaf1))
3. 根节点: Root = keccak256(abi.encodePacked(Hash01, Hash23))
```

#### 1.3 链下生成 Merkle 树 (前端)

**完整实现**: `frontend/utils/merkleTree.ts`

```typescript
/**
 * 构建 Merkle 树
 * @param addresses 白名单地址列表
 * @returns { root, leaves, layers }
 */
export function buildMerkleTree(addresses: Address[]): {
    root: `0x${string}`;
    leaves: `0x${string}`[];
    layers: `0x${string}`[][];
} {
    // 1. 计算所有叶子节点
    const leaves = addresses.map(addr => 
        keccak256(encodePacked(['address'], [addr]))
    );
    
    // 2. 排序叶子节点（保证一致性）
    const sortedLeaves = [...leaves].sort();
    
    // 3. 构建树的各层
    const layers: `0x${string}`[][] = [sortedLeaves];
    let currentLayer = sortedLeaves;
    
    while (currentLayer.length > 1) {
        const nextLayer: `0x${string}`[] = [];
        for (let i = 0; i < currentLayer.length; i += 2) {
            if (i + 1 < currentLayer.length) {
                // 两两配对
                nextLayer.push(hashPair(currentLayer[i], currentLayer[i + 1]));
            } else {
                // 奇数个节点时，最后一个与自己配对
                nextLayer.push(hashPair(currentLayer[i], currentLayer[i]));
            }
        }
        layers.push(nextLayer);
        currentLayer = nextLayer;
    }
    
    return {
        root: currentLayer[0],  // Merkle Root
        leaves: sortedLeaves,
        layers,
    };
}

// 排序并哈希两个节点
function hashPair(a: `0x${string}`, b: `0x${string}`): `0x${string}` {
    // 确保较小的哈希在前面，保证一致性
    const [left, right] = a < b ? [a, b] : [b, a];
    return keccak256(encodePacked(['bytes32', 'bytes32'], [left, right]));
}
```

**为什么要排序?**
- 保证相同的地址列表生成相同的 Merkle Root
- 避免顺序不同导致根哈希不同
- 提高一致性和可预测性

#### 1.4 生成 Merkle Proof

**Merkle Proof**: 从叶子节点到根节点路径上的所有兄弟节点

```typescript
/**
 * 获取地址的 Merkle 证明
 * @param addresses 完整的白名单地址列表
 * @param targetAddress 要获取证明的地址
 * @returns Merkle 证明数组
 */
export function getMerkleProof(
    addresses: Address[],
    targetAddress: Address
): `0x${string}`[] {
    const { leaves, layers } = buildMerkleTree(addresses);
    const targetLeaf = computeLeaf(targetAddress);
    
    let index = leaves.indexOf(targetLeaf);
    if (index === -1) {
        return []; // 地址不在白名单中
    }
    
    const proof: `0x${string}`[] = [];
    
    // 从叶子层向上遍历到根
    for (let i = 0; i < layers.length - 1; i++) {
        const layer = layers[i];
        const isRightNode = index % 2 === 1;
        const siblingIndex = isRightNode ? index - 1 : index + 1;
        
        if (siblingIndex < layer.length) {
            proof.push(layer[siblingIndex]);  // 添加兄弟节点
        } else {
            proof.push(layer[index]);  // 没有兄弟节点，使用自己
        }
        
        index = Math.floor(index / 2);  // 移动到父节点
    }
    
    return proof;
}
```

**Proof 示例**:

假设要证明 Addr2 在白名单中:
```
                    Root
                   /    \
              Hash01    Hash23
              /  \      /  \
          Leaf0 Leaf1 Leaf2 Leaf3
                         ↑
                      目标地址
```

**Merkle Proof**: `[Leaf3, Hash01]`

**验证过程**:
```
1. Hash23 = hash(Leaf2, Leaf3)  // 使用 Proof[0]
2. Root = hash(Hash01, Hash23)   // 使用 Proof[1]
3. 对比计算出的 Root 与链上存储的 Root
```

#### 1.5 链上验证 Merkle Proof

**合约实现**:

```solidity
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropMerkleNFTMarket {
    // 存储 Merkle Root
    bytes32 public merkleRoot;
    
    /// @notice 白名单用户购买 NFT
    function claimNFT(
        uint256 listingId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        // 1. 计算叶子节点
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        
        // 2. 验证 Merkle Proof
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidMerkleProof();
        }
        
        // 3. 执行购买逻辑...
    }
}
```

**OpenZeppelin MerkleProof.verify() 实现原理**:

```solidity
function verify(
    bytes32[] memory proof,
    bytes32 root,
    bytes32 leaf
) internal pure returns (bool) {
    bytes32 computedHash = leaf;
    
    for (uint256 i = 0; i < proof.length; i++) {
        // 排序后哈希
        computedHash = computedHash < proof[i]
            ? keccak256(abi.encodePacked(computedHash, proof[i]))
            : keccak256(abi.encodePacked(proof[i], computedHash));
    }
    
    return computedHash == root;
}
```

**验证流程**:
```
输入: leaf, proof = [Leaf3, Hash01], root
    ↓
Step 1: hash(Leaf2, Leaf3) = Hash23
    ↓
Step 2: hash(Hash01, Hash23) = Root'
    ↓
Step 3: Root' == Root ? ✓
```

#### 1.6 更新 Merkle Root

```solidity
/// @notice 更新 Merkle 树根
function setMerkleRoot(bytes32 _newRoot) external onlyAdmin {
    bytes32 oldRoot = merkleRoot;
    merkleRoot = _newRoot;
    emit MerkleRootUpdated(oldRoot, _newRoot);
}
```

**使用场景**:
- 添加新的白名单用户
- 移除白名单用户
- 更新白名单列表

**注意事项**:
- 仅管理员可调用
- 更新后，旧的 Merkle Proof 将失效
- 用户需要重新获取新的 Proof

---

### 2. EIP-2612 Permit 授权

#### 2.1 什么是 EIP-2612 Permit?

EIP-2612 是一种**离线签名授权**标准，允许用户通过签名授权 Token，无需单独发送 `approve` 交易。

**传统流程** (2 笔交易):
```
1. 用户调用 token.approve(spender, amount)  // 第 1 笔交易
2. 用户调用 market.buyNFT(...)               // 第 2 笔交易
```

**Permit 流程** (1 笔交易):
```
1. 用户离线签名授权 (无需上链)
2. 用户调用 market.permitAndBuy(signature, ...)  // 仅 1 笔交易
```

**优势**:
- ✅ 节省 gas (减少一笔交易)
- ✅ 改善用户体验 (一键完成)
- ✅ 支持元交易 (meta-transaction)

#### 2.2 ZZToken 实现 (ERC20Permit)

```solidity
// ZZToken.sol
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ZZTOKEN is ERC20, ERC20Permit {
    constructor() 
        ERC20("ZZTOKEN", "ZZ") 
        ERC20Permit("ZZTOKEN")  // 初始化 Permit
    {
        _mint(msg.sender, 100_000_000 * 10 ** decimals());
    }
}
```

**ERC20Permit 核心函数**:

```solidity
function permit(
    address owner,      // Token 持有者
    address spender,    // 授权给谁
    uint256 value,      // 授权金额
    uint256 deadline,   // 签名过期时间
    uint8 v,            // 签名参数
    bytes32 r,
    bytes32 s
) external;
```

#### 2.3 EIP-712 签名标准

**EIP-712** 定义了结构化数据的签名格式，使签名更安全、可读。

**Domain Separator** (域分隔符):
```solidity
struct EIP712Domain {
    string name;              // "ZZTOKEN"
    string version;           // "1"
    uint256 chainId;          // 31337 (Anvil)
    address verifyingContract; // Token 合约地址
}
```

**Permit 消息结构**:
```solidity
struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;     // 防重放
    uint256 deadline;
}
```

**签名数据计算**:
```
digest = keccak256(
    "\x19\x01" +
    DOMAIN_SEPARATOR +
    keccak256(PERMIT_TYPEHASH + encode(Permit))
)
```

#### 2.4 前端生成 Permit 签名

```typescript
// 1. 准备签名数据
const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 小时后过期
const nonce = await tokenContract.read.nonces([userAddress]);

// 2. 使用 wagmi 的 signTypedData
const signature = await signTypedDataAsync({
    domain: {
        name: 'ZZTOKEN',
        version: '1',
        chainId: 31337,
        verifyingContract: TOKEN_ADDRESS
    },
    types: {
        Permit: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' }
        ]
    },
    primaryType: 'Permit',
    message: {
        owner: userAddress,
        spender: MARKET_ADDRESS,
        value: parseEther(price),
        nonce,
        deadline
    }
});

// 3. 分离签名参数
const { v, r, s } = splitSignature(signature);
```

#### 2.5 合约调用 Permit

```solidity
/// @notice 调用 Token 的 permit 进行授权
function permitPrePay(
    address token,
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) external {
    IERC20Permit(token).permit(owner, spender, value, deadline, v, r, s);
}
```

**执行流程**:
```
1. 验证签名有效性
2. 验证 deadline 未过期
3. 验证 nonce 正确 (防重放)
4. 设置 allowance[owner][spender] = value
5. 递增 nonce
```

---

### 3. Multicall 批量调用

#### 3.1 什么是 Multicall?

Multicall 允许在**一次交易**中执行**多个函数调用**，常用于批量操作。

**使用场景**:
- Permit 授权 + 购买 NFT
- 批量查询数据
- 批量执行操作

**优势**:
- ✅ 节省 gas (减少交易数量)
- ✅ 原子性 (全部成功或全部失败)
- ✅ 改善用户体验

#### 3.2 delegatecall vs call

**call**:
- 在**目标合约**的上下文中执行
- `msg.sender` 变为调用者合约
- 状态变化发生在目标合约

**delegatecall**:
- 在**当前合约**的上下文中执行
- `msg.sender` 保持为原始调用者
- 状态变化发生在当前合约

**为什么使用 delegatecall?**

在 Multicall 中，我们需要保持 `msg.sender` 为实际用户，以便:
- `claimNFT` 中的 Merkle 验证能正确识别白名单用户
- Token 转账 `transferFrom(msg.sender, ...)` 能正确扣款

#### 3.3 Multicall 实现

```solidity
/// @notice 批量调用多个方法（使用 delegatecall）
function multicall(
    bytes[] calldata data
) external returns (bytes[] memory results) {
    results = new bytes[](data.length);
    
    for (uint256 i = 0; i < data.length; i++) {
        // 使用 delegatecall 保持 msg.sender
        (bool success, bytes memory result) = address(this).delegatecall(
            data[i]
        );
        
        if (!success) {
            revert MulticallFailed(i, result);
        }
        
        results[i] = result;
    }
}
```

**执行流程**:
```
用户调用 multicall([permitData, claimData])
    ↓
Loop 1: delegatecall(permitData)
    ↓ 在当前合约上下文执行
    permitPrePay(...) // msg.sender = 用户
    ↓
Loop 2: delegatecall(claimData)
    ↓ 在当前合约上下文执行
    claimNFT(...) // msg.sender = 用户
    ↓
返回结果
```

#### 3.4 前端编码调用数据

```typescript
// 1. 编码 permitPrePay 调用
const permitData = encodeFunctionData({
    abi: MARKET_ABI,
    functionName: 'permitPrePay',
    args: [
        TOKEN_ADDRESS,      // token
        userAddress,        // owner
        MARKET_ADDRESS,     // spender
        parseEther(price),  // value
        deadline,           // deadline
        v, r, s             // 签名参数
    ]
});

// 2. 编码 claimNFT 调用
const claimData = encodeFunctionData({
    abi: MARKET_ABI,
    functionName: 'claimNFT',
    args: [
        listingId,          // listingId
        merkleProof         // merkleProof
    ]
});

// 3. 调用 multicall
const tx = await writeContract({
    address: MARKET_ADDRESS,
    abi: MARKET_ABI,
    functionName: 'multicall',
    args: [[permitData, claimData]]  // 批量调用
});
```

#### 3.5 完整购买流程

```
用户点击"购买 NFT"
    ↓
1. 前端生成 Permit 签名 (离线)
    ↓
2. 编码 permitPrePay 和 claimNFT 调用数据
    ↓
3. 调用 multicall([permitData, claimData])
    ↓
4. 合约执行:
   a. delegatecall permitPrePay
      - 调用 token.permit() 授权
   b. delegatecall claimNFT
      - 验证 Merkle Proof
      - 计算 50% 折扣价格
      - 转移 Token (买家 -> 卖家)
      - 转移 NFT (合约 -> 买家)
    ↓
5. 交易成功，NFT 到账
```

---

### 4. 50% 折扣优惠

#### 4.1 折扣计算

```solidity
function claimNFT(
    uint256 listingId,
    bytes32[] calldata merkleProof
) external nonReentrant {
    // 1. 验证 Merkle Proof
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
    if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
        revert InvalidMerkleProof();
    }
    
    // 2. 获取原始价格
    Listing storage L = listings[listingId];
    uint256 originalPrice = L.price;
    
    // 3. 计算 50% 折扣价格
    uint256 discountedPrice = originalPrice / 2;
    
    // 4. 转移 Token (使用折扣价格)
    IERC20(L.payToken).transferFrom(
        msg.sender,
        L.seller,
        discountedPrice  // 仅支付 50%
    );
    
    // 5. 转移 NFT
    IERC721(L.nft).safeTransferFrom(address(this), msg.sender, L.tokenId);
    
    emit NFTClaimed(
        listingId,
        msg.sender,
        L.seller,
        L.nft,
        L.tokenId,
        L.payToken,
        originalPrice,      // 原价
        discountedPrice     // 折扣价
    );
}
```

#### 4.2 查询折扣价格

```solidity
/// @notice 计算折扣价格
function getDiscountedPrice(uint256 listingId) external view returns (uint256) {
    return listings[listingId].price / 2;
}
```

**前端使用**:
```typescript
const discountedPrice = await marketContract.read.getDiscountedPrice([listingId]);
console.log(`原价: ${price} ETH, 折扣价: ${discountedPrice} ETH`);
```

---

### 5. 上架 NFT (托管模式)

```solidity
/// @notice 上架 NFT
function list(
    address nft,
    uint256 tokenId,
    address payToken,
    uint256 price
) external nonReentrant returns (uint256 listingId) {
    // 1. 验证价格
    if (price == 0) revert InvalidPrice();
    
    // 2. 验证所有权
    address tokenOwner = IERC721(nft).ownerOf(tokenId);
    if (tokenOwner != msg.sender) revert NotOwner();
    
    // 3. 托管 NFT 到合约
    IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
    
    // 4. 创建上架记录
    listingId = nextListingId;
    unchecked {
        nextListingId = listingId + 1;
    }
    
    listings[listingId] = Listing({
        seller: msg.sender,
        active: true,
        nft: nft,
        tokenId: tokenId,
        payToken: payToken,
        price: price
    });
    
    emit Listed(listingId, msg.sender, nft, tokenId, payToken, price);
}
```

**托管模式特点**:
- NFT 转移到市场合约
- 卖家失去 NFT 控制权
- 购买时直接从合约转移给买家
- 安全可靠

---

## 🎨 前端功能

### 主要组件

| 组件 | 功能 | 说明 |
|------|------|------|
| `ListNFT.tsx` | 上架 NFT | 授权 + 上架 |
| `MerkleClaimNFT.tsx` | 白名单购买 | Permit 签名 + Multicall 购买 |
| `WhitelistManager.tsx` | 白名单管理 | 生成 Merkle Root 和 Proof |
| `AdminTools.tsx` | 管理员工具 | 铸造 NFT、转账 Token |
| `NFTListings.tsx` | 市场列表 | 显示所有上架 NFT |

### 核心代码示例

```typescript
// 白名单购买 NFT
const handleClaimNFT = async () => {
    // 1. 生成 Permit 签名
    const signature = await signTypedDataAsync({...});
    const { v, r, s } = splitSignature(signature);
    
    // 2. 编码调用数据
    const permitData = encodeFunctionData({
        functionName: 'permitPrePay',
        args: [token, owner, spender, value, deadline, v, r, s]
    });
    
    const claimData = encodeFunctionData({
        functionName: 'claimNFT',
        args: [listingId, merkleProof]
    });
    
    // 3. Multicall 执行
    await writeContract({
        functionName: 'multicall',
        args: [[permitData, claimData]]
    });
};
```

---

## 📖 使用流程

### 管理员操作

1. **铸造 NFT** - 使用 AdminTools 给卖家铸造 NFT
2. **转账 Token** - 给买家转账 ZZ Token
3. **设置白名单**:
   ```typescript
   // 输入地址列表
   const addresses = ['0x...', '0x...'];
   
   // 生成 Merkle Root
   const { root } = buildMerkleTree(addresses);
   
   // 设置到合约
   await marketContract.write.setMerkleRoot([root]);
   ```
4. **生成 Proof** - 为白名单用户生成 Merkle Proof

### 卖家操作

1. **授权 NFT**:
   ```typescript
   await nftContract.write.approve([MARKET_ADDRESS, tokenId]);
   ```
2. **上架 NFT**:
   ```typescript
   await marketContract.write.list([
       NFT_ADDRESS,
       tokenId,
       TOKEN_ADDRESS,
       parseEther(price)
   ]);
   ```

### 白名单买家操作

1. **获取 Merkle Proof**:
   ```typescript
   const proof = getMerkleProof(whitelistAddresses, userAddress);
   ```
2. **Multicall 购买** - 一键完成 Permit 签名 + Claim NFT

---

## 🧪 测试用例

### Merkle 验证测试
- ✅ `test_ClaimNFT_WithValidProof` - 有效 Proof 购买成功
- ✅ `test_ClaimNFT_WithInvalidProof_Reverts` - 无效 Proof 失败
- ✅ `test_IsWhitelisted` - 验证白名单状态

### 折扣测试
- ✅ `test_ClaimNFT_50PercentDiscount` - 50% 折扣验证
- ✅ `test_GetDiscountedPrice` - 折扣价格查询

### Permit 测试
- ✅ `test_PermitPrePay_Success` - Permit 授权成功
- ✅ `test_Multicall_PermitAndClaim` - Multicall 批量调用

### 管理功能测试
- ✅ `test_SetMerkleRoot` - 更新 Merkle Root
- ✅ `test_List_Success` - 上架 NFT

---

## 🛠️ 技术栈

### 智能合约
- **Solidity**: 0.8.30
- **框架**: Foundry
- **库**: OpenZeppelin Contracts
- **标准**: EIP-2612, EIP-712

### 前端
- **框架**: Next.js 16
- **Web3**: wagmi + viem
- **钱包**: RainbowKit
- **UI**: TailwindCSS

---

## 🔍 关键问题解决

### 1. 为什么使用 Merkle 树而非链上存储白名单?

**链上存储方案**:
```solidity
mapping(address => bool) public whitelist;  // 每个地址 20,000 gas
```

**Merkle 树方案**:
```solidity
bytes32 public merkleRoot;  // 仅 20,000 gas (一次性)
```

**对比**:
- 1000 个地址: 链上 20M gas vs Merkle 20k gas
- **节省**: ~99.9%

### 2. 为什么 Multicall 使用 delegatecall?

**使用 call**:
```solidity
address(this).call(data);
// msg.sender 变为合约地址
// claimNFT 中的 Merkle 验证会失败
```

**使用 delegatecall**:
```solidity
address(this).delegatecall(data);
// msg.sender 保持为用户地址
// claimNFT 中的 Merkle 验证能正确识别用户
```

### 3. 为什么需要 Permit?

**传统流程** (2 笔交易):
- 用户体验差
- Gas 成本高
- 需要等待两次确认

**Permit 流程** (1 笔交易):
- 一键完成
- 节省 gas
- 改善用户体验

---

## 📜 License

MIT

## 🙏 致谢

- [OpenZeppelin](https://www.openzeppelin.com/) - MerkleProof 库和 ERC20Permit
- [Foundry](https://getfoundry.sh/) - 智能合约开发框架
- [wagmi](https://wagmi.sh/) - React Hooks for Ethereum
