// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IUniswapV2Callee
 * @notice 闪电贷回调接口 Flash loan callback interface
 * @dev 实现此接口以使用Uniswap V2闪电贷功能
 * @dev Implement this interface to use Uniswap V2 flash loan functionality
 */
interface IUniswapV2Callee {
    /**
     * @notice 闪电贷回调函数 Flash loan callback function
     * @param sender 调用swap的地址 Address that called swap
     * @param amount0 借出的token0数量 Amount of token0 borrowed
     * @param amount1 借出的token1数量 Amount of token1 borrowed
     * @param data 自定义数据 Custom data
     */
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}
