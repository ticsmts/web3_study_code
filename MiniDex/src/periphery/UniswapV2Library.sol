// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswapV2Factory.sol";
import "../core/UniswapV2Pair.sol";

/**
 * @title UniswapV2Library
 * @notice Uniswap V2 辅助库 - 提供常用计算函数
 * @notice Uniswap V2 Helper Library - Provides common calculation functions
 *
 * 核心功能 Core Functions:
 * 1. 计算交易对地址(pairFor) / Calculate pair address (pairFor)
 * 2. 计算输出数量(getAmountOut) / Calculate output amount (getAmountOut)
 * 3. 计算输入数量(getAmountIn) / Calculate input amount (getAmountIn)
 * 4. 计算多跳路径的输出/输入 / Calculate multi-hop path outputs/inputs
 */
library UniswapV2Library {
    /**
     * @notice 代币排序 Sort tokens
     * @dev 确保token0 < token1，与Factory保持一致
     * @dev Ensure token0 < token1, consistent with Factory
     */
    function sortTokens(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }

    /**
     * @notice 计算交易对地址(无需调用Factory) Calculate pair address (without calling Factory)
     * @dev 使用CREATE2确定性地址计算 Uses CREATE2 deterministic address calculation
     *
     * ⚠️ 关键: INIT_CODE_HASH 必须与实际部署的Pair合约一致 ⚠️
     * ⚠️ CRITICAL: INIT_CODE_HASH must match the actually deployed Pair contract ⚠️
     *
     * 获取方法 How to obtain:
     * 1. 部署Factory后调用 factory.pairCodeHash() / Call factory.pairCodeHash() after deployment
     * 2. 或计算 keccak256(type(UniswapV2Pair).creationCode)
     * 3. 将返回的hash替换下面的INIT_CODE_HASH / Replace INIT_CODE_HASH below with returned hash
     *
     * 为什么需要硬编码 Why hardcode:
     * - CREATE2地址 = keccak256(0xff + factory + salt + init_code_hash)[12:]
     * - 硬编码避免每次调用factory.getPair()的gas开销
     * - Hardcoding avoids gas cost of calling factory.getPair() each time
     * - 使得链下也能计算交易对地址 / Enables off-chain pair address calculation
     *
     * @param factory 工厂合约地址 Factory contract address
     * @param tokenA 代币A Token A
     * @param tokenB 代币B Token B
     * @return pair 交易对地址 Pair address
     */
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);

        // ⚠️⚠️⚠️ 重要: 这个init code hash需要在部署后更新 ⚠️⚠️⚠️
        // ⚠️⚠️⚠️ IMPORTANT: This init code hash needs to be updated after deployment ⚠️⚠️⚠️
        //
        // 临时占位符值 Temporary placeholder value
        // 部署步骤 Deployment steps:
        // 1. 部署Factory Deploy Factory
        // 2. 调用factory.pairCodeHash()获取真实hash Call factory.pairCodeHash() to get real hash
        // 3. 用真实hash替换下面的INIT_CODE_PAIR_HASH Replace INIT_CODE_PAIR_HASH below with real hash
        //
        // 当前项目的 init_code_hash (已计算) Current project's init_code_hash (calculated)
        // 通过 cast keccak $(forge inspect UniswapV2Pair bytecode) 获取
        bytes32 INIT_CODE_PAIR_HASH = 0xd957d9319aa9c57e979e5c7eb31d7d064e6210694cfb559175779c891dde3c8d;

        pair = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            INIT_CODE_PAIR_HASH
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice 获取储备量 Get reserves
     * @dev 确保返回值顺序与tokenA/tokenB对应 Ensure return order matches tokenA/tokenB
     */
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) internal view returns (uint reserveA, uint reserveB) {
        (address token0, ) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1, ) = UniswapV2Pair(
            pairFor(factory, tokenA, tokenB)
        ).getReserves();
        (reserveA, reserveB) = tokenA == token0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    /**
     * @notice 给定输入资产数量，计算输出资产数量 Given input asset amount, calculate output asset amount
     * @dev 应用0.3%手续费的恒定乘积公式 Constant product formula with 0.3% fee
     *
     * 计算公式 Calculation Formula:
     * - amountOut = reserveOut * amountIn * 997 / (reserveIn * 1000 + amountIn * 997)
     * - 997/1000 = 0.997 (扣除0.3%手续费后) / 0.997 (after 0.3% fee deduction)
     *
     * 推导 Derivation:
     * - (reserveIn + amountIn * 0.997) * (reserveOut - amountOut) = reserveIn * reserveOut
     * - amountOut = reserveOut - (reserveIn * reserveOut) / (reserveIn + amountIn * 0.997)
     *
     * @param amountIn 输入数量 Input amount
     * @param reserveIn 输入代币储备 Input token reserve
     * @param reserveOut 输出代币储备 Output token reserve
     * @return amountOut 输出数量 Output amount
     */
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @notice 给定输出资产数量，计算所需输入资产数量 Given output asset amount, calculate required input asset amount
     * @dev 反向计算，确保能获得期望的输出数量 Reverse calculation to ensure desired output amount
     *
     * 计算公式 Calculation Formula:
     * - amountIn = reserveIn * amountOut * 1000 / ((reserveOut - amountOut) * 997) + 1
     * - +1 确保四舍五入误差不会导致交易失败 / +1 ensures rounding errors don't cause transaction failure
     *
     * @param amountOut 期望输出数量 Desired output amount
     * @param reserveIn 输入代币储备 Input token reserve
     * @param reserveOut 输出代币储备 Output token reserve
     * @return amountIn 所需输入数量 Required input amount
     */
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) internal pure returns (uint amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );

        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @notice 计算多跳路径的输出数量 Calculate output amounts for multi-hop path
     * @dev 沿路径顺序计算每一跳的输出 Calculate output for each hop along the path
     *
     * 示例 Example:
     * - path = [USDC, WETH, DAI]
     * - 计算 USDC -> WETH -> DAI 的最终输出
     * - Calculate final output for USDC -> WETH -> DAI
     *
     * @param factory 工厂合约地址 Factory contract address
     * @param amountIn 初始输入数量 Initial input amount
     * @param path 代币路径数组 Token path array
     * @return amounts 每一跳的数量数组 Amount array for each hop
     */
    function getAmountsOut(
        address factory,
        uint amountIn,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(
                factory,
                path[i],
                path[i + 1]
            );
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice 计算多跳路径的输入数量 Calculate input amounts for multi-hop path
     * @dev 从路径末端反向计算每一跳的输入 Calculate input for each hop in reverse from path end
     *
     * @param factory 工厂合约地址 Factory contract address
     * @param amountOut 期望最终输出 Desired final output
     * @param path 代币路径数组 Token path array
     * @return amounts 每一跳的数量数组(反向) Amount array for each hop (reverse)
     */
    function getAmountsIn(
        address factory,
        uint amountOut,
        address[] memory path
    ) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, "UniswapV2Library: INVALID_PATH");
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(
                factory,
                path[i - 1],
                path[i]
            );
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice 给定两个数，返回较小值 Return smaller of two numbers
     */
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    /**
     * @notice 根据储备量计算兑换比例 Calculate exchange ratio based on reserves
     * @dev 给定amountA，按比例计算对应的amountB Calculate corresponding amountB proportionally given amountA
     *
     * @param amountA A代币数量 Amount of token A
     * @param reserveA A的储备量 Reserve of A
     * @param reserveB B的储备量 Reserve of B
     * @return amountB 对应的B代币数量 Corresponding amount of token B
     */
    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) internal pure returns (uint amountB) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        amountB = (amountA * reserveB) / reserveA;
    }
}
