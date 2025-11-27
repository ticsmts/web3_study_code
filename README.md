# Web3 Study Code

记录我在学习web3过程中的coding。

## 1. PoW 实践题（decert.me）

文件：`pow_decert_01.py`  

题目链接：https://decert.me/challenge/45779e03-7905-469e-822e-3ec3746d9ece 

功能：用昵称 + nonce 进行 SHA256 计算，模拟工作量证明，寻找满足指定前导  个数的哈希值。

### 运行方式

```bash
python3 pow_decert_01.py
```


文件：`pow_decert_args.py` 

功能： 给pow_decert_01.py添加命令行功能

功能：命令行接受--name 昵称，及--zeros 前置0数量，实现命令行功能。

```bash
python3 pow_decert_args.py --name ticsmts --zeros 5
```
