pragma solidity ^0.8.20;

/*
    一个状态变量 counter
    get()方法: 获取 counter 的值
    add(x) 方法: 给变量加上 x 。

    https://remix.ethereum.org/
    合约地址:  0x8eb9990D5e2f1e8a681b575aBa321df2711C3f3C
    调用add方法: https://sepolia.etherscan.io/tx/0xe8c7c9034573ebc0e1292cb24dc8bceacd62558f04ae09c452f6678b9a6ae289

*/
contract CounterToken{
    uint256 public counter = 0;
    
    constructor(uint256 initValue){
        counter = initValue;
    }

    function get() external view returns (uint256){
        return counter;
    }

    function add(uint256 x) external {
        counter += x;
    }        

}