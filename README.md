# Web3 Study Code

记录我在学习web3过程中的coding。

## 1. PoW 实践题 

文件: `pow_decert_01.py`  

题目链接: https://decert.me/quests/45779e03-7905-469e-822e-3ec3746d9ece 

功能: 用昵称 + nonce 进行 SHA256 计算，模拟工作量证明，寻找满足指定前导  个数的哈希值。

### 运行方式

```bash
python3 pow_decert_01.py
```
---

文件: `pow_decert_cli.py` 

功能:  给pow_decert_01.py添加命令行功能

功能: 命令行接受--name 昵称，及--zeros 前置0数量，实现命令行功能。

```bash
python3 pow_decert_cli.py --name ticsmts --zeros 5
```

---
文件: pow_rsa_sign.py  

题目链接: https://decert.me/quests/45779e03-7905-469e-822e-3ec3746d9ece

功能:  对挖矿结果进行签名，然后使用公钥进行验证。

```bash
python3 pow_rsa_sign.py --name ticsmts --zeros 5
```

---
## 2. 模拟实现最小的区块链
文件: `mini_blockchain.py`

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
文件: `helloWorld_Solidity.sol`

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