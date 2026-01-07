// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IERC20.sol";
import "./UniswapV2Library.sol";
import "../core/UniswapV2Pair.sol";

/**
 * @title UniswapV2Router02
 * @notice Uniswap V2 路由合约 - 用户交互的主要入口
 * @notice Uniswap V2 Router Contract - Main entry point for user interactions
 *
 * 核心功能 Core Functions:
 * 1. 添加/移除流动性 / Add/remove liquidity
 * 2. 单跳和多跳代币兑换 / Single-hop and multi-hop token swaps
 * 3. 滑点保护 / Slippage protection
 * 4. 截止时间检查 / Deadline checks
 * 5. 路径路由 / Path routing
 *
 * 为什么需要Router Why Router is needed:
 * - Pair合约是底层协议，直接使用不方便
 * - Pair contract is low-level protocol, inconvenient to use directly
 * - Router提供用户友好的接口和安全检查
 * - Router provides user-friendly interface and safety checks
 * - 处理多跳交易路径 / Handles multi-hop trading paths
 */
contract UniswapV2Router02 is IUniswapV2Router02 {
    address public immutable override factory;
    address public immutable override WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        factory = _factory;
        WETH = _WETH;
    }

    /**
     * @notice 添加流动性 Add liquidity
     * @dev 为tokenA/tokenB交易对添加流动性 Add liquidity to tokenA/tokenB pair
     *
     * 工作流程 Workflow:
     * 1. 如果交易对不存在，创建交易对 / Create pair if doesn't exist
     * 2. 计算最优添加数量 / Calculate optimal amounts to add
     * 3. 转移代币到交易对 / Transfer tokens to pair
     * 4. 调用pair.mint铸造LP代币 / Call pair.mint to mint LP tokens
     *
     * 滑点保护 Slippage Protection:
     * - amountAMin/amountBMin: 用户可接受的最小数量
     * - amountAMin/amountBMin: Minimum amounts user accepts
     * - 如果实际数量低于最小值，交易回滚
     * - Transaction reverts if actual amount lower than minimum
     *
     * @param tokenA 代币A地址 Token A address
     * @param tokenB 代币B地址 Token B address
     * @param amountADesired 期望添加的A数量 Desired amount A
     * @param amountBDesired 期望添加的B数量 Desired amount B
     * @param amountAMin A的最小数量 Minimum amount A
     * @param amountBMin B的最小数量 Minimum amount B
     * @param to LP代币接收地址 LP token recipient
     * @param deadline 截止时间 Deadline timestamp
     * @return amountA 实际添加的A数量 Actual amount A added
     * @return amountB 实际添加的B数量 Actual amount B added
     * @return liquidity 获得的LP代币数量 LP tokens received
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    )
        external
        override
        ensure(deadline)
        returns (uint amountA, uint amountB, uint liquidity)
    {
        // 如果交易对不存在则创建 Create pair if it doesn't exist
        if (IUniswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IUniswapV2Factory(factory).createPair(tokenA, tokenB);
        }

        // 计算最优添加数量 Calculate optimal amounts
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        // 获取交易对地址 Get pair address
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        // 转移代币到交易对 Transfer tokens to pair
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);

        // 铸造LP代币 Mint LP tokens
        liquidity = UniswapV2Pair(pair).mint(to);
    }

    /**
     * @dev Calculate optimal liquidity amounts - internal helper
     * 计算最优添加流动性数量 - 内部辅助函数
     */
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) private view returns (uint amountA, uint amountB) {
        (uint reserveA, uint reserveB) = UniswapV2Library.getReserves(
            factory,
            tokenA,
            tokenB
        );

        if (reserveA == 0 && reserveB == 0) {
            // 首次添加，使用期望数量 First addition, use desired amounts
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            // 按储备比例计算amountB Calculate amountB based on reserve ratio
            uint amountBOptimal = UniswapV2Library.quote(
                amountADesired,
                reserveA,
                reserveB
            );

            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                // 按储备比例计算amountA Calculate amountA based on reserve ratio
                uint amountAOptimal = UniswapV2Library.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                require(
                    amountAOptimal <= amountADesired &&
                        amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /**
     * @notice 移除流动性 Remove liquidity
     * @dev 销毁LP代币，赎回底层资产 Burn LP tokens, redeem underlying assets
     *
     * 工作流程 Workflow:
     * 1. 将LP代币转移到交易对 / Transfer LP tokens to pair
     * 2. 调用pair.burn销毁并获取代币 / Call pair.burn to burn and receive tokens
     * 3. 检查赎回数量满足最小要求 / Check redeemed amounts meet minimum requirements
     *
     * @param tokenA 代币A Token A
     * @param tokenB 代币B Token B
     * @param liquidity 销毁的LP代币数量 LP tokens to burn
     * @param amountAMin A的最小赎回数量 Minimum A to redeem
     * @param amountBMin B的最小赎回数量 Minimum B to redeem
     * @param to 资产接收地址 Asset recipient
     * @param deadline 截止时间 Deadline
     * @return amountA 赎回的A数量 Redeemed amount A
     * @return amountB 赎回的B数量 Redeemed amount B
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);

        // 将LP代币转移到交易对 Transfer LP tokens to pair
        IERC20(pair).transferFrom(msg.sender, pair, liquidity);

        // 销毁LP代币并获取底层资产 Burn LP tokens and receive underlying assets
        (uint amount0, uint amount1) = UniswapV2Pair(pair).burn(to);

        // 排序输出 Sort outputs
        (address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);

        // 验证滑点保护 Verify slippage protection
        require(
            amountA >= amountAMin,
            "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
        );
    }

    /**
     * @notice 精确输入代币兑换 Swap exact tokens in
     * @dev 用户指定输入数量，获得至少amountOutMin的输出
     * @dev User specifies input amount, receives at least amountOutMin output
     *
     * 多跳路径 Multi-hop Path:
     * - path = [tokenA, tokenB, tokenC]
     * - 执行 tokenA -> tokenB -> tokenC 的连续兑换
     * - Execute consecutive swaps: tokenA -> tokenB -> tokenC
     *
     * 示例 Example:
     * - 用1000 USDC换WETH，最少获得0.5 WETH
     * - Swap 1000 USDC for WETH, receive at least 0.5 WETH
     * - path = [USDC, WETH]
     *
     * @param amountIn 输入代币数量 Input token amount
     * @param amountOutMin 最小输出数量 Minimum output amount
     * @param path 代币路径 Token path
     * @param to 接收地址 Recipient
     * @param deadline 截止时间 Deadline
     * @return amounts 每一跳的数量 Amounts for each hop
     */
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        // 计算路径上每一跳的输出数量 Calculate output amount for each hop
        amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);

        // 验证最终输出满足最小要求 Verify final output meets minimum requirement
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );

        // 将输入代币转移到第一个交易对 Transfer input tokens to first pair
        _safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );

        // 执行沿路径的兑换 Execute swaps along path
        _swap(amounts, path, to);
    }

    /**
     * @notice 精确输出代币兑换 Swap tokens for exact output
     * @dev 用户指定期望输出，支付不超过amountInMax的输入
     * @dev User specifies desired output, pays at most amountInMax input
     *
     * 示例 Example:
     * - 想获得10 WETH，最多支付20000 USDC
     * - Want to receive 10 WETH, pay at most 20000 USDC
     * - path = [USDC, WETH]
     *
     * @param amountOut 期望输出数量 Desired output amount
     * @param amountInMax 最大输入数量 Maximum input amount
     * @param path 代币路径 Token path
     * @param to 接收地址 Recipient
     * @param deadline 截止时间 Deadline
     * @return amounts 每一跳的数量 Amounts for each hop
     */
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        // 反向计算所需输入 Calculate required input in reverse
        amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);

        // 验证所需输入不超过最大值 Verify required input doesn't exceed maximum
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );

        // 将输入代币转移到第一个交易对 Transfer input tokens to first pair
        _safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );

        // 执行兑换 Execute swaps
        _swap(amounts, path, to);
    }

    /**
     * @dev Execute consecutive swaps along path - internal helper
     * 沿路径执行连续兑换 - 内部辅助函数
     */
    function _swap(
        uint[] memory amounts,
        address[] memory path,
        address _to
    ) private {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];

            // 判断输出是token0还是token1 Determine if output is token0 or token1
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOut)
                : (amountOut, uint(0));

            // 确定接收地址: 最后一跳发给用户，否则发给下一个pair
            // Determine recipient: last hop to user, otherwise to next pair
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(factory, output, path[i + 2])
                : _to;

            // 执行兑换 Execute swap
            UniswapV2Pair(UniswapV2Library.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /**
     * @notice 查询给定输入的输出数量 Query output amounts for given input
     * @dev 不执行交易，仅查询 View function, doesn't execute trade
     */
    function getAmountsOut(
        uint amountIn,
        address[] memory path
    ) public view override returns (uint[] memory amounts) {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    /**
     * @notice 查询给定输出所需的输入数量 Query required input for given output
     * @dev 不执行交易，仅查询 View function, doesn't execute trade
     */
    function getAmountsIn(
        uint amountOut,
        address[] memory path
    ) public view override returns (uint[] memory amounts) {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }

    /// @dev Safe ERC20 transfer from - internal helper
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint value
    ) private {
        IERC20(token).transferFrom(from, to, value);
    }
}
