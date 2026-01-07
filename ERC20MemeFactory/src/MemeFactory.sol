// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MemeToken.sol";
import "./interfaces/IMiniDex.sol";

/**
 * @title MemeFactory
 * @dev Meme 代币工厂合约，使用 ERC1167 最小代理模式部署代币
 * @notice Meme token factory using ERC1167 minimal proxy pattern
 *
 * 功能 Features:
 * 1. deployMeme() - 使用最小代理部署 Meme 代币
 * 2. mintMeme() - 铸造 Meme 代币，费用分配 5% 项目方, 95% 发行者
 * 3. buyMeme() - 通过 DEX 购买（价格更优时）
 * 4. 自动添加流动性到 MiniDex
 */
contract MemeFactory {
    using Clones for address;

    /// @notice 项目方地址 / Project owner address
    address public immutable owner;

    /// @notice MemeToken 实现合约地址 / MemeToken implementation address
    address public immutable tokenImplementation;

    /// @notice MiniDex Router 地址 / MiniDex Router address
    address public immutable router;

    /// @notice WETH 地址 / WETH address
    address public immutable weth;

    /// @notice 项目方费用比例 (5%) / Project fee percentage
    uint256 public constant PROJECT_FEE_PERCENT = 5;

    /// @notice Meme 代币信息 / Meme token info
    struct MemeInfo {
        address creator; // 发行者 / Creator
        string symbol; // 符号 / Symbol
        uint256 totalSupply; // 总发行量 / Total supply
        uint256 perMint; // 每次铸造数量 / Per mint amount
        uint256 price; // 每个代币价格 (wei) / Price per token in wei
        bool exists; // 是否存在 / Exists flag
    }

    /// @notice Meme 代币地址 => 信息 / Token address to info mapping
    mapping(address => MemeInfo) public memes;

    /// @notice 所有已部署的 Meme 代币地址列表 / All deployed meme token addresses
    address[] public allMemes;

    /// @notice 项目方累计收益 / Accumulated project fees
    uint256 public projectFees;

    // ============ Events ============

    event MemeDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );

    event MemeMinted(
        address indexed token,
        address indexed buyer,
        uint256 amount,
        uint256 cost
    );

    event MemeBought(
        address indexed token,
        address indexed buyer,
        uint256 amount,
        uint256 cost,
        bool usedDex
    );

    event LiquidityAdded(
        address indexed token,
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 liquidity
    );

    event FeesDistributed(
        address indexed token,
        address indexed creator,
        uint256 creatorFee,
        uint256 projectFee
    );

    // ============ Errors ============

    error InvalidParameters();
    error MemeNotFound();
    error InsufficientPayment();
    error ExceedsTotalSupply();
    error TransferFailed();
    error NotOwner();

    // ============ Constructor ============

    constructor(address _tokenImplementation, address _router, address _weth) {
        if (
            _tokenImplementation == address(0) ||
            _router == address(0) ||
            _weth == address(0)
        ) {
            revert InvalidParameters();
        }
        owner = msg.sender;
        tokenImplementation = _tokenImplementation;
        router = _router;
        weth = _weth;
    }

    // ============ External Functions ============

    /**
     * @notice 部署新的 Meme 代币
     * @dev Deploy a new Meme token using minimal proxy
     */
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address memeToken) {
        if (
            bytes(symbol).length == 0 ||
            totalSupply == 0 ||
            perMint == 0 ||
            price == 0
        ) {
            revert InvalidParameters();
        }
        if (perMint > totalSupply) {
            revert InvalidParameters();
        }

        memeToken = tokenImplementation.clone();

        MemeToken(memeToken).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,
            address(this)
        );

        memes[memeToken] = MemeInfo({
            creator: msg.sender,
            symbol: symbol,
            totalSupply: totalSupply,
            perMint: perMint,
            price: price,
            exists: true
        });

        allMemes.push(memeToken);

        emit MemeDeployed(
            memeToken,
            msg.sender,
            symbol,
            totalSupply,
            perMint,
            price
        );
    }

    /**
     * @notice 铸造 Meme 代币
     * @dev Mint Meme tokens, distributes fees: 5% to project, 95% to creator
     */
    function mintMeme(address tokenAddr) external payable {
        MemeInfo storage info = memes[tokenAddr];
        if (!info.exists) revert MemeNotFound();

        MemeToken token = MemeToken(tokenAddr);
        uint256 mintCost = token.getMintCost();
        if (msg.value < mintCost) revert InsufficientPayment();

        if (token.totalMinted() + info.perMint > info.totalSupply) {
            revert ExceedsTotalSupply();
        }

        token.mint(msg.sender);
        _distributeFees(tokenAddr, mintCost, info.creator);

        if (msg.value > mintCost) {
            _safeTransferETH(msg.sender, msg.value - mintCost);
        }

        emit MemeMinted(tokenAddr, msg.sender, info.perMint, mintCost);
    }

    /**
     * @notice 通过 DEX 购买 Meme（价格更优时）
     * @dev Buy Meme via DEX when price is better
     */
    function buyMeme(address tokenAddr) external payable {
        MemeInfo storage info = memes[tokenAddr];
        if (!info.exists) revert MemeNotFound();
        if (msg.value == 0) revert InsufficientPayment();

        MemeToken token = MemeToken(tokenAddr);
        uint256 dexOutput = _getDexOutput(tokenAddr, msg.value);

        uint256 mintCost = token.getMintCost();
        uint256 mintableTimes = msg.value / mintCost;
        uint256 mintOutput = mintableTimes * info.perMint;
        bool canMint = token.totalMinted() + info.perMint <= info.totalSupply;

        if (dexOutput > mintOutput && dexOutput > 0) {
            _buyViaDex(tokenAddr, msg.value, dexOutput, msg.sender);
            emit MemeBought(tokenAddr, msg.sender, dexOutput, msg.value, true);
        } else if (canMint && mintableTimes > 0) {
            uint256 actualCost = mintableTimes * mintCost;
            uint256 actualMinted = 0;

            for (uint256 i = 0; i < mintableTimes; i++) {
                if (token.totalMinted() + info.perMint > info.totalSupply)
                    break;
                token.mint(msg.sender);
                _distributeFees(tokenAddr, mintCost, info.creator);
                actualMinted += info.perMint;
            }

            if (msg.value > actualCost) {
                _safeTransferETH(msg.sender, msg.value - actualCost);
            }

            emit MemeBought(
                tokenAddr,
                msg.sender,
                actualMinted,
                actualCost,
                false
            );
        } else if (dexOutput > 0) {
            _buyViaDex(tokenAddr, msg.value, dexOutput, msg.sender);
            emit MemeBought(tokenAddr, msg.sender, dexOutput, msg.value, true);
        } else {
            revert ExceedsTotalSupply();
        }
    }

    function getMemesCount() external view returns (uint256) {
        return allMemes.length;
    }

    function getMemeInfo(
        address tokenAddr
    )
        external
        view
        returns (
            address creator,
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            uint256 totalMinted,
            uint256 remainingSupply
        )
    {
        MemeInfo storage info = memes[tokenAddr];
        if (!info.exists) revert MemeNotFound();

        MemeToken token = MemeToken(tokenAddr);
        return (
            info.creator,
            info.symbol,
            info.totalSupply,
            info.perMint,
            info.price,
            token.totalMinted(),
            token.remainingSupply()
        );
    }

    function withdrawFees() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 amount = projectFees;
        if (amount == 0) revert InvalidParameters();
        projectFees = 0;
        _safeTransferETH(owner, amount);
    }

    // ============ Internal Functions ============

    function _distributeFees(
        address tokenAddr,
        uint256 totalFee,
        address creator
    ) internal {
        uint256 projectFee = (totalFee * PROJECT_FEE_PERCENT) / 100;
        uint256 creatorFee = totalFee - projectFee;

        _safeTransferETH(creator, creatorFee);
        _addLiquidity(tokenAddr, projectFee);

        emit FeesDistributed(tokenAddr, creator, creatorFee, projectFee);
    }

    function _addLiquidity(address tokenAddr, uint256 ethAmount) internal {
        MemeInfo storage info = memes[tokenAddr];
        MemeToken token = MemeToken(tokenAddr);

        // Check if we can mint tokens for liquidity
        if (token.totalMinted() + info.perMint > info.totalSupply) {
            projectFees += ethAmount;
            return;
        }

        // Check if router and weth have contract code deployed
        // If not, accumulate fees instead of trying to add liquidity
        if (router.code.length == 0 || weth.code.length == 0) {
            projectFees += ethAmount;
            return;
        }

        // Convert ETH to WETH
        IWETH(weth).deposit{value: ethAmount}();

        // Check if liquidity pool exists
        address dexFactory;
        try IUniswapV2Router02(router).factory() returns (address _factory) {
            dexFactory = _factory;
        } catch {
            // Router call failed, refund WETH and accumulate fees
            try IWETH(weth).withdraw(ethAmount) {} catch {}
            projectFees += ethAmount;
            return;
        }

        address pair;
        try IUniswapV2Factory(dexFactory).getPair(tokenAddr, weth) returns (address _pair) {
            pair = _pair;
        } catch {
            // Factory call failed, refund WETH and accumulate fees
            try IWETH(weth).withdraw(ethAmount) {} catch {}
            projectFees += ethAmount;
            return;
        }

        if (pair == address(0)) {
            // First time adding liquidity
            _addFirstLiquidity(tokenAddr, ethAmount, token, info);
        } else {
            // Pool exists, add proportionally
            _addExistingLiquidity(tokenAddr, ethAmount, token, info, pair);
        }
    }

    function _addFirstLiquidity(
        address tokenAddr,
        uint256 ethAmount,
        MemeToken token,
        MemeInfo storage info
    ) internal {
        if (token.totalMinted() + info.perMint <= info.totalSupply) {
            token.mint(address(this));

            IERC20(tokenAddr).approve(router, info.perMint);
            IWETH(weth).approve(router, ethAmount);

            try
                IUniswapV2Router02(router).addLiquidity(
                    tokenAddr,
                    weth,
                    info.perMint,
                    ethAmount,
                    0,
                    0,
                    address(this),
                    block.timestamp + 300
                )
            returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
                emit LiquidityAdded(tokenAddr, amountA, amountB, liquidity);
            } catch {
                projectFees += ethAmount;
            }
        } else {
            projectFees += ethAmount;
        }
    }

    function _addExistingLiquidity(
        address tokenAddr,
        uint256 ethAmount,
        MemeToken token,
        MemeInfo storage info,
        address pair
    ) internal {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        address token0 = IUniswapV2Pair(pair).token0();

        uint256 tokenReserve = token0 == tokenAddr ? reserve0 : reserve1;
        uint256 wethReserve = token0 == tokenAddr ? reserve1 : reserve0;

        if (wethReserve == 0 || tokenReserve == 0) {
            _addFirstLiquidity(tokenAddr, ethAmount, token, info);
            return;
        }

        uint256 requiredTokens = (ethAmount * tokenReserve) / wethReserve;
        uint256 mintsNeeded = requiredTokens / info.perMint;
        if (mintsNeeded == 0) {
            mintsNeeded = 1;
        }

        if (token.totalMinted() + info.perMint > info.totalSupply) {
            projectFees += ethAmount;
            return;
        }

        uint256 actualTokens = 0;
        for (uint256 i = 0; i < mintsNeeded && i < 10; i++) {
            if (token.totalMinted() + info.perMint > info.totalSupply) break;
            token.mint(address(this));
            actualTokens += info.perMint;
        }

        if (actualTokens > 0) {
            IERC20(tokenAddr).approve(router, actualTokens);
            IWETH(weth).approve(router, ethAmount);

            try
                IUniswapV2Router02(router).addLiquidity(
                    tokenAddr,
                    weth,
                    actualTokens,
                    ethAmount,
                    0,
                    0,
                    address(this),
                    block.timestamp + 300
                )
            returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
                emit LiquidityAdded(tokenAddr, amountA, amountB, liquidity);
            } catch {
                projectFees += ethAmount;
            }
        } else {
            projectFees += ethAmount;
        }
    }

    function _getDexOutput(
        address tokenAddr,
        uint256 ethAmount
    ) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenAddr;

        try IUniswapV2Router02(router).getAmountsOut(ethAmount, path) returns (
            uint256[] memory amounts
        ) {
            return amounts[1];
        } catch {
            return 0;
        }
    }

    function _buyViaDex(
        address tokenAddr,
        uint256 ethAmount,
        uint256 minOutput,
        address recipient
    ) internal {
        IWETH(weth).deposit{value: ethAmount}();
        IWETH(weth).approve(router, ethAmount);

        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = tokenAddr;

        IUniswapV2Router02(router).swapExactTokensForTokens(
            ethAmount,
            (minOutput * 95) / 100,
            path,
            recipient,
            block.timestamp + 300
        );
    }

    function _safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    receive() external payable {}
}
