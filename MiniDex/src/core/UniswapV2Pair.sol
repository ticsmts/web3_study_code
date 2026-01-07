// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UniswapV2ERC20.sol";
import "../libraries/Math.sol";
import "../libraries/UQ112x112.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Callee.sol";

/**
 * @title UniswapV2Pair
 * @notice Uniswap V2 交易对合约 - AMM的核心实现
 * @notice Uniswap V2 Pair Contract - Core AMM implementation
 *
 * 核心机制 Core Mechanisms:
 * 1. 恒定乘积公式 x * y = k / Constant Product Formula x * y = k
 * 2. 流动性提供与移除 / Liquidity provision and removal
 * 3. 代币兑换 / Token swapping
 * 4. 闪电贷 / Flash loans
 * 5. 价格预言机 / Price oracle
 * 6. 0.3% 交易费用 / 0.3% trading fee
 */
contract UniswapV2Pair is UniswapV2ERC20 {
    using UQ112x112 for uint224;

    // 最小流动性锁定量: 1000 wei永久锁定，防止除零错误
    // Minimum liquidity locked: 1000 wei permanently locked to prevent division by zero
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;

    // transfer函数选择器，用于优化调用
    // transfer function selector for optimized calls
    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    // 工厂合约地址 Factory contract address
    address public factory;

    // 交易对中的两个代币地址 Two token addresses in the pair
    address public token0;
    address public token1;

    // 储备量(使用uint112节省gas，支持到5e15个代币)
    // Reserves (uint112 saves gas, supports up to 5e15 tokens)
    uint112 private reserve0;
    uint112 private reserve1;

    // 最后更新时间戳(uint32可表示到2106年)
    // Last update timestamp (uint32 valid until year 2106)
    uint32 private blockTimestampLast;

    // 价格累积值，用于TWAP价格预言机
    // Price accumulators for TWAP price oracle
    // 公式: price0Cumulative += (reserve1 / reserve0) * timeElapsed
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;

    // 最后一次交易后的k值，用于计算协议手续费
    // k value after last trade, used for protocol fee calculation
    uint public kLast;

    // 重入锁 Reentrancy lock
    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    // 事件 Events
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {
        factory = msg.sender;
    }

    /**
     * @notice 初始化交易对 Initialize trading pair
     * @dev 仅工厂合约可调用 Only callable by factory
     */
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    /**
     * @notice 获取当前储备量 Get current reserves
     * @return _reserve0 代币0储备量 Token0 reserves
     * @return _reserve1 代币1储备量 Token1 reserves
     * @return _blockTimestampLast 最后更新时间 Last update timestamp
     */
    function getReserves()
        public
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @notice 安全转账ERC20代币 Safe ERC20 transfer
     * @dev 使用低级call避免返回值不一致问题 Uses low-level call to avoid return value inconsistencies
     */
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "UniswapV2: TRANSFER_FAILED"
        );
    }

    /**
     * @notice 更新储备量和价格累积值 Update reserves and price accumulators
     * @dev 核心价格预言机逻辑 Core price oracle logic
     *
     * TWAP原理 TWAP Principle:
     * - 每个区块更新价格累积值 / Update price accumulator each block
     * - price = (priceCumulative_end - priceCumulative_start) / timeElapsed
     * - 使用UQ112x112定点数格式存储价格 / Use UQ112x112 fixed-point format for prices
     */
    function _update(
        uint balance0,
        uint balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        // 确保余额不会溢出uint112
        // Ensure balances don't overflow uint112
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "UniswapV2: OVERFLOW"
        );

        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        // 如果时间流逝 且 储备量不为0，更新价格累积值
        // If time elapsed and reserves not zero, update price accumulators
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // 使用UQ112x112格式: reserve1/reserve0 * timeElapsed
            // UQ112x112 format: reserve1/reserve0 * timeElapsed
            price0CumulativeLast +=
                uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) *
                timeElapsed;
            price1CumulativeLast +=
                uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) *
                timeElapsed;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    /**
     * @notice 铸造协议手续费 Mint protocol fee
     * @dev 如果feeTo设置，从增长的k值中收取1/6的手续费
     * @dev If feeTo is set, collect 1/6 fee from k growth
     *
     * 手续费计算 Fee Calculation:
     * - 总手续费0.3%，其中1/6(0.05%)归协议，5/6(0.25%)归LP
     * - Total fee 0.3%, where 1/6(0.05%) goes to protocol, 5/6(0.25%) to LPs
     * - liquidity = totalSupply * (√k_new - √k_old) / (5 * √k_new + √k_old)
     */
    function _mintFee(
        uint112 _reserve0,
        uint112 _reserve1
    ) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0) * uint(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);

                if (rootK > rootKLast) {
                    uint numerator = totalSupply * (rootK - rootKLast);
                    uint denominator = rootK * 5 + rootKLast;
                    uint liquidity = numerator / denominator;

                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /**
     * @notice 添加流动性 Add liquidity
     * @dev 铸造LP代币给流动性提供者 Mint LP tokens to liquidity provider
     *
     * 首次添加流动性 First liquidity addition:
     * - liquidity = √(amount0 * amount1) - MINIMUM_LIQUIDITY
     * - MINIMUM_LIQUIDITY锁定到0地址防止除零 / MINIMUM_LIQUIDITY locked to prevent division by zero
     *
     * 后续添加 Subsequent additions:
     * - liquidity = min(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1)
     *
     * @param to LP代币接收地址 LP token recipient
     * @return liquidity 铸造的LP代币数量 Amount of LP tokens minted
     */
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        // 获取当前合约余额 Get current contract balances
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));

        // 计算新增数量 Calculate added amounts
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        // 铸造协议手续费 Mint protocol fee
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;

        if (_totalSupply == 0) {
            // 首次添加流动性 First liquidity addition
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // 永久锁定 Permanently lock
        } else {
            // 按比例铸造LP代币 Mint LP tokens proportionally
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        require(liquidity > 0, "UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * uint(reserve1);

        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @notice 移除流动性 Remove liquidity
     * @dev 销毁LP代币，返还底层资产 Burn LP tokens, return underlying assets
     *
     * 计算公式 Calculation:
     * - amount0 = liquidity * balance0 / totalSupply
     * - amount1 = liquidity * balance1 / totalSupply
     *
     * @param to 资产接收地址 Asset recipient
     * @return amount0 返还的token0数量 Amount of token0 returned
     * @return amount1 返还的token1数量 Amount of token1 returned
     */
    function burn(
        address to
    ) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        address _token0 = token0;
        address _token1 = token1;

        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;

        // 按比例计算返还数量 Calculate proportional amounts to return
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        require(
            amount0 > 0 && amount1 > 0,
            "UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED"
        );

        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0) * uint(reserve1);

        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @notice 代币兑换 Token swap
     * @dev 核心交易函数，实现恒定乘积做市商 Core trading function implementing constant product AMM
     *
     * 恒定乘积公式 Constant Product Formula:
     * - (x + Δx * 0.997) * (y - Δy) >= x * y
     * - 0.3%手续费: 实际输入 = amountIn * 0.997
     * - 0.3% fee: Actual input = amountIn * 0.997
     *
     * 闪电贷支持 Flash Loan Support:
     * - 先转出代币，后验证k值 / Transfer out first, verify k value later
     * - 允许在回调中执行任意逻辑 / Allow arbitrary logic in callback
     *
     * @param amount0Out token0输出数量 Token0 output amount
     * @param amount1Out token1输出数量 Token1 output amount
     * @param to 接收地址 Recipient address
     * @param data 回调数据(非空则触发闪电贷回调) Callback data (triggers flash loan callback if non-empty)
     */
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external lock {
        require(
            amount0Out > 0 || amount1Out > 0,
            "UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        require(
            amount0Out < _reserve0 && amount1Out < _reserve1,
            "UniswapV2: INSUFFICIENT_LIQUIDITY"
        );

        uint balance0;
        uint balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");

            // 乐观转账: 先转出代币 Optimistic transfer: transfer out first
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);

            // 闪电贷回调 Flash loan callback
            if (data.length > 0)
                IUniswapV2Callee(to).uniswapV2Call(
                    msg.sender,
                    amount0Out,
                    amount1Out,
                    data
                );

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }

        // 计算实际输入数量 Calculate actual input amounts
        uint amount0In = balance0 > _reserve0 - amount0Out
            ? balance0 - (_reserve0 - amount0Out)
            : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out
            ? balance1 - (_reserve1 - amount1Out)
            : 0;
        require(
            amount0In > 0 || amount1In > 0,
            "UniswapV2: INSUFFICIENT_INPUT_AMOUNT"
        );

        {
            // 验证恒定乘积公式(扣除0.3%手续费后)
            // Verify constant product formula (after 0.3% fee deduction)
            // balance * 1000 - amountIn * 3 相当于 balance * 0.997
            // balance * 1000 - amountIn * 3 equivalent to balance * 0.997
            uint balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(
                balance0Adjusted * balance1Adjusted >=
                    uint(_reserve0) * uint(_reserve1) * (1000 ** 2),
                "UniswapV2: K"
            );
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @notice 强制同步储备量到实际余额 Force sync reserves to actual balances
     * @dev 用于处理直接转账到合约的代币 Handles tokens transferred directly to contract
     */
    function skim(address to) external lock {
        address _token0 = token0;
        address _token1 = token1;
        _safeTransfer(
            _token0,
            to,
            IERC20(_token0).balanceOf(address(this)) - reserve0
        );
        _safeTransfer(
            _token1,
            to,
            IERC20(_token1).balanceOf(address(this)) - reserve1
        );
    }

    /**
     * @notice 强制同步储备量 Force sync reserves
     * @dev 将储备量更新为当前余额 Update reserves to current balances
     */
    function sync() external lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }
}
