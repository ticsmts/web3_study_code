# Web3 Study Code

记录我在学习web3过程中的coding。

## 1. PoW 实践题 

文件：`pow_decert_01.py`  

题目链接：https://decert.me/challenge/45779e03-7905-469e-822e-3ec3746d9ece 

功能：用昵称 + nonce 进行 SHA256 计算，模拟工作量证明，寻找满足指定前导  个数的哈希值。

### 运行方式

```bash
python3 pow_decert_01.py
```
---

文件：`pow_decert_cli.py` 

功能： 给pow_decert_01.py添加命令行功能

功能：命令行接受--name 昵称，及--zeros 前置0数量，实现命令行功能。

```bash
python3 pow_decert_cli.py --name ticsmts --zeros 5
```

---
文件： pow_rsa_sign.py  

题目链接：https://decert.me/challenge/45779e03-7905-469e-822e-3ec3746d9ece

功能: 对挖矿结果进行签名，然后使用公钥进行验证。

```bash
python3 pow_rsa_sign.py --name ticsmts --zeros 5
```

---
## 2. 模拟实现最小的区块链
文件：`mini_blockchain.py`

题目链接：https://decert.me/challenge/ed2d8324-54b0-4b7a-9cee-5e97d3c30030

功能：

模拟实现最小的区块链， 包含两个功能：
1. POW 证明出块，难度为 4 个 0 开头 
2. 每个区块包含previous_hash 让区块串联起来。

```bash
python3 mini_blockchain.py
```