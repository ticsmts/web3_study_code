# 命令行wallet
## 题目要求
编写一个脚本（可以基于 Viem.js 、Ethers.js 或其他的库来实现）来模拟一个命令行钱包，钱包包含的功能有：

1. 生成私钥、查询余额（可人工转入金额）
2. 构建一个 ERC20 转账的 EIP 1559 交易
3. 用 1 生成的账号，对 ERC20 转账进行签名
4. 发送交易到 Sepolia 网络。

## 简单实现
### 生成私钥，地址
![生成新地址](images/image.png)

### 查询地址余额
![查询地址余额](images/image-1.png)

### 打包交易信息
![打包交易信息](images/image-3.png)

![交易信息](images/image-4.png)

### 对交易进行签名
![构造交易信息](images/image-2.png)
![签名后信息](images/image-5.png)

### 发送交易
![发送交易](images/image-6.png)

### 一键打包签名发送交易
![一次性打包签名发送交易](images/image-7.png)

![查询余额](images/image-8.png)