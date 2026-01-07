// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Math
 * @notice 数学工具库 Mathematical utility library
 */
library Math {
    /**
     * @notice 计算平方根(巴比伦方法/牛顿迭代法)
     * @notice Calculate square root (Babylonian method / Newton's method)
     * @dev 用于计算几何平均数 √(x*y) 以确定初始LP代币数量
     * @dev Used to calculate geometric mean √(x*y) to determine initial LP token amount
     */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     * @notice 返回两个数的最小值 Return minimum of two numbers
     */
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }
}
