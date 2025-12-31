# Web3 Study Code

记录我在学习web3过程中的coding。

## 1. PoW 实践题 

文件: `BlockchainBasics\pow_decert_01.py`  

题目链接: https://decert.me/quests/45779e03-7905-469e-822e-3ec3746d9ece 

功能: 用昵称 + nonce 进行 SHA256 计算，模拟工作量证明，寻找满足指定前导  个数的哈希值。

### 运行方式

```bash
python3 pow_decert_01.py
```
---

文件: `BlockchainBasics\pow_decert_cli.py` 

功能:  给pow_decert_01.py添加命令行功能

功能: 命令行接受--name 昵称，及--zeros 前置0数量，实现命令行功能。

```bash
python3 pow_decert_cli.py --name ticsmts --zeros 5
```

---
文件: `BlockchainBasics\pow_rsa_sign.py`  

题目链接: https://decert.me/quests/45779e03-7905-469e-822e-3ec3746d9ece

功能:  对挖矿结果进行签名，然后使用公钥进行验证。

```bash
python3 pow_rsa_sign.py --name ticsmts --zeros 5
```

---
## 2. 模拟实现最小的区块链
文件: `BlockchainBasics\mini_blockchain.py`

题目链接: https://decert.me/quests/ed2d8324-54b0-4b7a-9cee-5e97d3c30030

功能: 

模拟实现最小的区块链， 包含两个功能: 
1. POW 证明出块，难度为 4 个 0 开头 
2. 每个区块包含previous_hash 让区块串联起来。

```bash
python3 mini_blockchain.py
```

---
## 3. Solidity 
文件: `Hello_Solidity.sol`

题目链接: https://decert.me/quests/61289231665986005978714272641295754558731174328007379661370918963875971676821

功能:

使用 Remix 创建一个 Counter 合约并部署到任意以太坊测试网:
Counter 合约具有
 1. 一个状态变量 counter
 2. get()方法: 获取 counter 的值
 3. add(x) 方法: 给变量加上 x 。

---
# 4. Solidity 实现基础Bank 
文件: `Bank\Bank.sol`

题目链接: https://decert.me/quests/c43324bc-0220-4e81-b533-668fa644c1c3

功能:

编写一个 Bank 合约，实现功能:
   1. 可以通过 Metamask 等钱包直接给 Bank 合约地址存款
   2. 在 Bank 合约记录每个地址的存款金额
   3. 编写 withdraw() 方法，仅管理员可以通过该方法提取资金。
   4. 用数组记录存款金额的前 3 名用户

---

文件: `Bank\BigBank.sol`

题目链接: https://decert.me/quests/063c14be-d3e6-41e0-a243-54e35b1dde58

功能:

编写IBank接口及BigBank合约，使其满足Bank实现IBank接口，BigBank继承自Bank，同时BigBank有附加要求：

    1. 要求存款金额大于0.001 ether（用modifier权限控制）
    2. BigBank合约支持转移管理员。编写一个Admin合约， Admin合约有自己的Owner, 同时有一个取款函数adminWithdraw(IBank bank), adminWithdraw 中会调用 IBank 接口的withdraw方法从而把bank合约内的资金转移到Admin合约地址。
    3. BigBank和Admin合约部署后，把BigBank的管理员转移给Admin合约地址，模拟几个用户的存款，然后Admin合约的Owner地址调用adminWithdraw(IBank bank) 把BigBank的资金转移到Admin地址。



----
# 5. 实现 ERC20 代币合约
文件: `ERC20\ERC20.sol`

题目链接: https://decert.me/quests/aa45f136-27a3-4bc9-b4f7-15308e1e0daa

功能:

完成简单ERC20代币合约，实现查看余额，授权，转账等基本功能。

---
文件: `ERC20\ZZTokenBank.sol`

题目链接: https://decert.me/quests/eeb9f7d8-6fd0-4c38-b09c-75a29bd53af3

功能:

编写一个 TokenBank 合约，可以将自己的 Token 存入到 TokenBank， 和从 TokenBank 取出。TokenBank 有两个方法：

    1. deposit() : 需要记录每个地址的存入数量；
    2. withdraw（）: 用户可以提取自己的之前存入的 token。
---

文件: `ERC20\ZZTokenBankV2.sol`

题目链接: https://decert.me/quests/4df553df-fbab-49c8-a05f-83256432c6af

功能:

扩展 ERC20 合约 ，添加一个有hook 功能的转账函数，如函数名为：transferWithCallback ，在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法。
    
    1. 继承 TokenBank 编写 TokenBankV2，支持存入扩展的 ERC20 Token，用户可以直接调用 transferWithCallback 将扩展的 ERC20 Token 存入到 TokenBankV2 中。
    2. TokenBankV2 需要实现 tokensReceived 来实现存款记录工作。
---

# 6. 补充：Solidity基础 代码学习
文件夹: `solidity_basics`

功能:

Solidity 基础知识，方便查阅，后续补充完整。

---

# 7. 学习 ERC721 NFT 相关知识
文件: `ERC721\ERC721.sol`

题目链接: https://decert.me/quests/44422409934343079786063971789166937234174343060396376783106591556071947050149

功能:

创建一个遵循 ERC721 标准的智能合约，该合约能够用于在以太坊区块链上铸造与交易 NFT。

---
文件: `ERC721\NFTMarket\ZZNFTMarket.sol`

题目链接: https://decert.me/quests/94799378334494196719554698703092354231387604736360075935626034744730539670014

功能:


    编写一个简单的NFTMarket合约，使用自己发行的ERC20 扩展 Token 来买卖 NFT，NFTMarket 的函数有：

    1. list(): 实现上架功能，NFT 持有者可以设定一个价格（需要多少个 Token购买该NFT）并上架 NFT 到 NFTMarket，上架之后，其他人才可以购买。
    2. buyNFT(): 普通的购买NFT功能，用户转入所定价的token数量，获得对应的NFT。
    3. 实现ERC20扩展Token所要求的接收者方法tokensReceived ，在 tokensReceived中实现NFT购买功能(注意扩展的转账需要添加一个额外数据参数)。

# 8. Foundry 开发框架学习

文件夹: `ERC20\OpenZeppelinERC20`

题目链接: https://decert.me/quests/4df553df-fbab-49c8-a05f-83256432c6af

功能: 

    将下方合约部署到 https://sepolia.etherscan.io/ ，要求如下:
    1. 要求使用你在 Decert.met 登录的钱包来部署合约  
    2. 要求贴出编写 forge script 的脚本合约  
    3. 合约在 https://sepolia.etherscan.io/ 中开源

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MyToken is ERC20 { 
    constructor(string name_, string symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 1e10*1e18);
    } 
}

```
---

题目链接: https://decert.me/quests/10006

题目描述: Foundry 基础知识相关测试。

---

文件夹: `Foundry\TestStudy`

题目链接: 
https://decert.me/quests/10006


功能:

    为 Bank 合约 编写测试。测试Case包含：
    1. 断言检查存款前后用户在 Bank 合约中的存款额更新是否正确。
    2. 检查存款金额的前 3 名用户是否正确，分别检查有1个、2个、3个、4 个用户， 以及同一个用户多次存款的情况。
    3. 检查只有管理员可取款，其他人不可以取款。

---

# 9. Dapp 前端知识学习

文件夹: `ERC20\tokenbank-viem-demo`

题目链接: 
https://decert.me/quests/56e455b3-901c-415d-90c0-a20759469cf9

使用 Viem 为 TokenBank 搭建一个简单的前端

功能:
    
    给 Token Bank 添加前端界面：
    1. 显示当前 Token 的余额，并且可以存款(点击按钮存款)到 TokenBank
    2. 存款后显示用户存款金额，同时支持用户取款(点击按钮取款)。

---

文件夹: `dapp-frontends\nftmarket-listener`

题目链接: 
https://decert.me/quests/b4698649-25b2-45ae-9bb5-23da0c49e491

使⽤Viem.sh监听NFTMarket的买卖记录

功能:
    
    在NFTMarket 合约中在上架（list）和买卖函数（buyNFT 及 tokensReceived）中添加相应事件，在后台监听上架和购买事件，如果链上发生了上架或购买行为，打印出相应的日志。

---

文件夹: `dapp-frontends\zznftmarket-frontend`

题目链接: 
https://decert.me/quests/a1a9aff6-1788-4254-bc47-405cc529bbd1

NFTMarket项目接入 AppKit 登录

功能:
    
    1. 为 NFTMarket 项目添加前端，并接入 AppKit 进行前端登录，并实际操作使用 WalletConnect 进行登录（需要先安装手机端钱包）。
    2. 在 NFTMarket 前端添加上架操作，切换另一个账号后可使用 Token 进行购买 NFT。

---

# 10. viem库学习

文件夹: `erc20_indexer/`

题目链接: 
https://decert.me/quests/ae220513-c0cb-4d9b-873a-caee1d4b358e

使用 Viem 索引链上ERC20 转账数据并展示 

功能:
    
    1. 后端索引出之前自己发行的 ERC20 Token 转账, 并保存到数据库。
    2. 提供一个 Restful 接口来获取某一个地址的转账记录。
    3. 实现前端，用户登录后， 从后端查询出该用户地址的转账记录， 并展示。

---

# 11. 钱包相关知识学习

文件夹: `cli_wallet/`

题目链接: 
https://decert.me/quests/992dae0f-3bdf-4f03-9798-3427234fad95

使用Viem构建一个CLI钱包

功能:
    
    模拟一个命令行钱包，基于Viem.js，钱包包含的功能有：
    1. 生成私钥、查询账户余额
    2. 构建一个 ERC20 转账的 EIP 1559 交易
    3. 用生成的账号对 ERC20 转账进行签名
    4. 发送交易到 Sepolia 网络

---

文件夹: `MultiSigWallet/`

题目链接: 
https://decert.me/quests/f832d7a2-2806-4ad9-8560-a27ad8570c6f

功能：

    实现⼀个简单的多签合约钱包，合约包含的功能：
    1. 创建多签钱包时，确定所有的多签持有⼈和签名门槛
    2. 多签持有⼈可提交提案
    3. 其他多签⼈确认提案（使⽤交易的⽅式确认即可）
    4. 达到多签⻔槛、任何⼈都可以执⾏交易

---

# 12. 账户抽象及签名

文件夹: `EIP712_EIP7702/`

题目链接: 
https://decert.me/quests/2c550f3e-0c29-46f8-a9ea-6258bb01b3ff

功能:

    TokenBank Dapp项目，一个展示四种不同 ERC20 代币存款方式的完整前端应用，使用 RainbowKit + Wagmi + Viem 构建，实现4种存款方式对比：
    1. V1: Approve + Deposit
    2. V2: TransferWithCallback
    3. V3: Permit + PermitDeposit
    4. V4: EIP-7702 Batch
    5. V5: Permit2 

---

文件夹: `ZZNFTMarketV3/`

题目链接: 
https://decert.me/quests/fc66ef6c-35db-4ee7-b11d-c3b2d3fa356a


功能:
    
    实现功能 `permitBuy()` 实现只有离线授权的白名单地址才可以购买 NFT。白名单具体实现逻辑为：
    1. 项目方给白名单地址签名
    2. 白名单用户拿到签名信息
    3. 传给 `permitBuy()` 函数，在`permitBuy()`中判断时候是经过许可的白名单用户，如果是，才可以进行后续购买，否则 revert 。

---
文件夹: `InscriptionContractFactory/`

题目链接: 
https://decert.me/challenge/ac607bb0-53b5-421f-a9df-f3db4a1495f2

功能:
    V1:
    
    实现⼀个可升级的工厂合约，工厂合约有两个方法： 
    1. deployInscription(string symbol, uint totalSupply, uint perMint) ，该方法用来创建 ERC20 token，（类似模拟铭文的 deploy）， symbol 表示 Token 的名称，totalSupply 表示可发行的数量，perMint 用来控制每次发行的数量，用于控制mintInscription函数每次发行的数量
    2. mintInscription(address tokenAddr) 用来发行 ERC20 token，每次调用一次，发行perMint指定的数量。

    V2:
    1. deployInscription 加入一个价格参数 price:  
    deployInscription(string symbol, uint totalSupply, uint perMint, uint price) ，price 表示发行每个 token 需要支付的费用，
    2. 使用最小代理的方式以更节约 gas 的方式来创建 ERC20 token，需要同时修改 mintInscription 的实现以便收取每次发行的费用。 


