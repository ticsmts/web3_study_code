// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MemeToken.sol";
import "../src/MemeFactory.sol";
import "../src/interfaces/IMiniDex.sol";

/**
 * @title MockWETH
 * @dev 模拟 WETH 合约 / Mock WETH contract
 */
contract MockWETH {
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Approval(address indexed src, address indexed guy, uint256 wad);

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        require(balanceOf[msg.sender] >= wad, "Insufficient balance");
        balanceOf[msg.sender] -= wad;
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public returns (bool) {
        if (
            src != msg.sender && allowance[src][msg.sender] != type(uint256).max
        ) {
            require(
                allowance[src][msg.sender] >= wad,
                "Insufficient allowance"
            );
            allowance[src][msg.sender] -= wad;
        }
        require(balanceOf[src] >= wad, "Insufficient balance");
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(src, dst, wad);
        return true;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    receive() external payable {
        deposit();
    }
}

/**
 * @title MockRouter
 * @dev 模拟 UniswapV2Router / Mock UniswapV2Router
 */
contract MockRouter {
    address public factory;
    address public WETH;

    mapping(address => mapping(address => address)) public pairs;
    mapping(address => uint256) public tokenReserves;
    mapping(address => uint256) public wethReserves;

    constructor(address _factory, address _weth) {
        factory = _factory;
        WETH = _weth;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint,
        uint,
        address to,
        uint
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        // 简化的流动性添加 / Simplified liquidity addition
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        // 更新储备 / Update reserves
        if (tokenA < tokenB) {
            tokenReserves[tokenA] += amountADesired;
            wethReserves[tokenA] += amountBDesired;
        } else {
            tokenReserves[tokenB] += amountBDesired;
            wethReserves[tokenB] += amountADesired;
        }

        return (amountADesired, amountBDesired, amountADesired);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint
    ) external returns (uint[] memory amounts) {
        require(path.length == 2, "Invalid path");

        // 简化的 swap / Simplified swap
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        // 计算输出 / Calculate output
        uint256 amountOut = (amountIn * tokenReserves[path[1]]) /
            wethReserves[path[1]];
        require(amountOut >= amountOutMin, "Insufficient output");

        IERC20(path[1]).transfer(to, amountOut);

        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts) {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;

        if (path.length == 2 && wethReserves[path[1]] > 0) {
            amounts[1] =
                (amountIn * tokenReserves[path[1]]) /
                wethReserves[path[1]];
        }
    }

    function setReserves(
        address token,
        uint256 tokenRes,
        uint256 wethRes
    ) external {
        tokenReserves[token] = tokenRes;
        wethReserves[token] = wethRes;
    }
}

/**
 * @title MockFactory
 * @dev 模拟 UniswapV2Factory / Mock UniswapV2Factory
 */
contract MockFactory {
    mapping(address => mapping(address => address)) public getPair;

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        pair = address(
            uint160(uint256(keccak256(abi.encodePacked(tokenA, tokenB))))
        );
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }

    function setPair(address tokenA, address tokenB, address pair) external {
        getPair[tokenA][tokenB] = pair;
        getPair[tokenB][tokenA] = pair;
    }
}

/**
 * @title MemeFactoryTest
 * @dev MemeFactory 完整测试用例 / Complete test cases for MemeFactory
 */
contract MemeFactoryTest is Test {
    MemeToken public tokenImplementation;
    MemeFactory public factory;
    MockWETH public weth;
    MockRouter public router;
    MockFactory public dexFactory;

    address public owner;
    address public creator;
    address public buyer;

    uint256 public constant TOTAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant PER_MINT = 1000 * 1e18;
    uint256 public constant PRICE = 0.001 ether; // 0.001 ETH per token

    function setUp() public {
        owner = address(this);
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");

        // 部署 Mock 合约 / Deploy mock contracts
        weth = new MockWETH();
        dexFactory = new MockFactory();
        router = new MockRouter(address(dexFactory), address(weth));

        // 部署 MemeToken 实现合约 / Deploy MemeToken implementation
        tokenImplementation = new MemeToken();

        // 部署 MemeFactory / Deploy MemeFactory
        factory = new MemeFactory(
            address(tokenImplementation),
            address(router),
            address(weth)
        );

        // 给测试账户一些 ETH / Give test accounts some ETH
        vm.deal(creator, 100 ether);
        vm.deal(buyer, 100 ether);
    }

    // ============ deployMeme 测试 ============

    function test_DeployMeme_Success() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        // 验证代币已部署 / Verify token is deployed
        assertTrue(memeToken != address(0), "Token should be deployed");

        // 验证代币信息 / Verify token info
        (
            address tokenCreator,
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            uint256 totalMinted,
            uint256 remainingSupply
        ) = factory.getMemeInfo(memeToken);

        assertEq(tokenCreator, creator, "Creator should match");
        assertEq(symbol, "PEPE", "Symbol should match");
        assertEq(totalSupply, TOTAL_SUPPLY, "Total supply should match");
        assertEq(perMint, PER_MINT, "Per mint should match");
        assertEq(price, PRICE, "Price should match");
        assertEq(totalMinted, 0, "Total minted should be 0");
        assertEq(remainingSupply, TOTAL_SUPPLY, "Remaining should equal total");
    }

    function test_DeployMeme_InvalidParams() public {
        vm.startPrank(creator);

        // 空符号 / Empty symbol
        vm.expectRevert(MemeFactory.InvalidParameters.selector);
        factory.deployMeme("", TOTAL_SUPPLY, PER_MINT, PRICE);

        // 零总量 / Zero total supply
        vm.expectRevert(MemeFactory.InvalidParameters.selector);
        factory.deployMeme("PEPE", 0, PER_MINT, PRICE);

        // 零 perMint / Zero per mint
        vm.expectRevert(MemeFactory.InvalidParameters.selector);
        factory.deployMeme("PEPE", TOTAL_SUPPLY, 0, PRICE);

        // 零价格 / Zero price
        vm.expectRevert(MemeFactory.InvalidParameters.selector);
        factory.deployMeme("PEPE", TOTAL_SUPPLY, PER_MINT, 0);

        // perMint > totalSupply
        vm.expectRevert(MemeFactory.InvalidParameters.selector);
        factory.deployMeme("PEPE", 100, 200, PRICE);

        vm.stopPrank();
    }

    function test_DeployMeme_MultipleTokens() public {
        vm.startPrank(creator);

        address token1 = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );
        address token2 = factory.deployMeme(
            "DOGE",
            TOTAL_SUPPLY * 2,
            PER_MINT * 2,
            PRICE / 2
        );
        address token3 = factory.deployMeme(
            "SHIB",
            TOTAL_SUPPLY / 2,
            PER_MINT / 2,
            PRICE * 2
        );

        vm.stopPrank();

        assertEq(factory.getMemesCount(), 3, "Should have 3 memes");
        assertTrue(token1 != token2, "Tokens should be different");
        assertTrue(token2 != token3, "Tokens should be different");
    }

    // ============ mintMeme 测试 ============

    function test_MintMeme_Success() public {
        // 部署 Meme / Deploy Meme
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        // 计算铸造费用 / Calculate mint cost
        uint256 mintCost = (PER_MINT * PRICE) / 1e18; // 1000 * 0.001 = 1 ETH

        // 购买者铸造 / Buyer mints
        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        // 验证购买者收到代币 / Verify buyer received tokens
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT,
            "Buyer should have tokens"
        );

        // 验证 totalMinted / Verify total minted
        // Note: totalMinted includes liquidity minting (1 perMint for user + 1 for liquidity)
        assertGe(
            MemeToken(memeToken).totalMinted(),
            PER_MINT,
            "Total minted should increase"
        );
    }

    function test_MintMeme_CorrectFeeDistribution() public {
        // 部署 Meme / Deploy Meme
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18; // 1 ETH

        // 记录初始余额 / Record initial balances
        uint256 creatorBalanceBefore = creator.balance;

        // 购买者铸造 / Buyer mints
        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        // 验证费用分配 / Verify fee distribution
        uint256 expectedCreatorFee = (mintCost * 95) / 100; // 95%

        // creator 应该收到 95% / Creator should receive 95%
        assertEq(
            creator.balance - creatorBalanceBefore,
            expectedCreatorFee,
            "Creator should receive 95%"
        );
    }

    function test_MintMeme_CreatorReceives95Percent() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = 1 ether;
        uint256 creatorBalanceBefore = creator.balance;

        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        uint256 creatorReceived = creator.balance - creatorBalanceBefore;
        uint256 expected95Percent = (mintCost * 95) / 100;

        assertEq(
            creatorReceived,
            expected95Percent,
            "Creator should receive exactly 95%"
        );
    }

    function test_MintMeme_ProjectReceives5Percent() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = 1 ether;

        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        // 5% 应该在工厂合约中（作为 WETH 或累积费用）或在 Router 中（作为流动性）
        // 5% should be in factory (as WETH or accumulated fees) or in Router (as liquidity)
        uint256 expected5Percent = (mintCost * 5) / 100;

        // 检查 projectFees、工厂 WETH 余额、或 Router WETH 余额
        uint256 projectFees = factory.projectFees();
        uint256 factoryWethBalance = weth.balanceOf(address(factory));
        uint256 routerWethBalance = weth.balanceOf(address(router));

        // 5% 应该在工厂中或已添加到流动性
        // 5% should be in factory or added to liquidity
        assertEq(
            projectFees + factoryWethBalance + routerWethBalance,
            expected5Percent,
            "Project should receive 5%"
        );
    }

    function test_MintMeme_ExceedsTotalSupply() public {
        // 部署小总量的 Meme / Deploy Meme with small total supply
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            PER_MINT,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18;

        // 第一次铸造成功 / First mint succeeds
        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        // 第二次铸造失败 / Second mint fails
        vm.prank(buyer);
        vm.expectRevert(MemeFactory.ExceedsTotalSupply.selector);
        factory.mintMeme{value: mintCost}(memeToken);
    }

    function test_MintMeme_PerMintCorrect() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18;

        // 铸造多次 / Mint multiple times
        vm.startPrank(buyer);

        factory.mintMeme{value: mintCost}(memeToken);
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT,
            "Should have 1x perMint"
        );

        factory.mintMeme{value: mintCost}(memeToken);
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT * 2,
            "Should have 2x perMint"
        );

        factory.mintMeme{value: mintCost}(memeToken);
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT * 3,
            "Should have 3x perMint"
        );

        vm.stopPrank();

        // 验证每次发行数量正确 / Verify per mint amount is correct
        // Note: totalMinted includes liquidity minting
        assertGe(
            MemeToken(memeToken).totalMinted(),
            PER_MINT * 3,
            "Total minted should be at least 3x perMint"
        );
    }

    function test_MintMeme_InsufficientPayment() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18;

        // 支付不足 / Insufficient payment
        vm.prank(buyer);
        vm.expectRevert(MemeFactory.InsufficientPayment.selector);
        factory.mintMeme{value: mintCost - 0.1 ether}(memeToken);
    }

    function test_MintMeme_RefundsExcess() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18;
        uint256 excess = 0.5 ether;
        uint256 buyerBalanceBefore = buyer.balance;

        // 多付 0.5 ETH / Overpay by 0.5 ETH
        vm.prank(buyer);
        factory.mintMeme{value: mintCost + excess}(memeToken);

        // 验证退款 / Verify refund
        uint256 actualCost = buyerBalanceBefore - buyer.balance;
        assertEq(actualCost, mintCost, "Only mint cost should be deducted");
    }

    // ============ 流动性测试 ============

    function test_MintMeme_AddsLiquidity() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = 1 ether;

        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        // 5% 应该被添加到流动性或累积 / 5% should be added to liquidity or accumulated
        uint256 expected5Percent = (mintCost * 5) / 100;

        // 检查所有可能的位置 / Check all possible locations
        uint256 factoryWethBalance = weth.balanceOf(address(factory));
        uint256 routerWethBalance = weth.balanceOf(address(router));
        uint256 projectFees = factory.projectFees();

        // 5% 应该在工厂中（WETH 或累积费用）或在 Router 中（作为流动性）
        assertTrue(
            factoryWethBalance > 0 || projectFees > 0 || routerWethBalance > 0,
            "5% should be in factory or router"
        );

        // 总金额应该等于 5%
        assertEq(
            factoryWethBalance + projectFees + routerWethBalance,
            expected5Percent,
            "Total 5% should be tracked"
        );
    }

    // ============ buyMeme 测试 ============

    function test_BuyMeme_UsesMintWhenNoDex() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18;

        // DEX 没有流动性，应该使用 mint / No DEX liquidity, should use mint
        vm.prank(buyer);
        factory.buyMeme{value: mintCost}(memeToken);

        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT,
            "Should have minted tokens"
        );
    }

    function test_BuyMeme_UsesMintWhenCheaper() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        // 设置 DEX 价格更贵 / Set DEX price higher
        // mint 价格: 1 ETH 获得 1000 tokens
        // DEX 价格: 1 ETH 获得 500 tokens (更贵)
        router.setReserves(memeToken, 500 * 1e18, 1 ether);

        uint256 mintCost = 1 ether;

        vm.prank(buyer);
        factory.buyMeme{value: mintCost}(memeToken);

        // 应该使用 mint / Should use mint
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT,
            "Should use mint when cheaper"
        );
    }

    // ============ 其他测试 ============

    function test_WithdrawFees_Success() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        // 多次铸造累积费用 / Mint multiple times to accumulate fees
        uint256 mintCost = 1 ether;

        vm.startPrank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);
        factory.mintMeme{value: mintCost}(memeToken);
        vm.stopPrank();

        // 获取累积费用 / Get accumulated fees
        uint256 projectFees = factory.projectFees();

        if (projectFees > 0) {
            uint256 ownerBalanceBefore = owner.balance;

            // Owner 提取费用 / Owner withdraws fees
            factory.withdrawFees();

            assertEq(
                owner.balance - ownerBalanceBefore,
                projectFees,
                "Owner should receive all project fees"
            );
        }
    }

    function test_WithdrawFees_OnlyOwner() public {
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        vm.prank(buyer);
        factory.mintMeme{value: 1 ether}(memeToken);

        // 非 owner 无法提取 / Non-owner cannot withdraw
        vm.prank(buyer);
        vm.expectRevert(MemeFactory.NotOwner.selector);
        factory.withdrawFees();
    }

    function test_MemeNotFound() public {
        vm.prank(buyer);
        vm.expectRevert(MemeFactory.MemeNotFound.selector);
        factory.mintMeme{value: 1 ether}(address(0x123));
    }

    function test_GetMemesCount() public {
        assertEq(factory.getMemesCount(), 0, "Should start with 0");

        vm.startPrank(creator);
        factory.deployMeme("PEPE", TOTAL_SUPPLY, PER_MINT, PRICE);
        assertEq(factory.getMemesCount(), 1, "Should have 1");

        factory.deployMeme("DOGE", TOTAL_SUPPLY, PER_MINT, PRICE);
        assertEq(factory.getMemesCount(), 2, "Should have 2");
        vm.stopPrank();
    }

    // ============ Edge case: invalid router/weth ============

    function test_MintMeme_WithInvalidRouterWeth() public {
        // Deploy a new factory with invalid router/weth addresses (no code)
        MemeFactory factoryNoRouter = new MemeFactory(
            address(tokenImplementation),
            address(0x1), // No contract code
            address(0x2) // No contract code
        );

        // Deploy a meme token
        vm.prank(creator);
        address memeToken = factoryNoRouter.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        uint256 mintCost = (PER_MINT * PRICE) / 1e18;
        uint256 creatorBalanceBefore = creator.balance;

        // Mint should succeed even with invalid router/weth
        // Fees should be accumulated instead of added to liquidity
        vm.prank(buyer);
        factoryNoRouter.mintMeme{value: mintCost}(memeToken);

        // Verify buyer received tokens
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT,
            "Buyer should have tokens"
        );

        // Verify creator received 95%
        uint256 expectedCreatorFee = (mintCost * 95) / 100;
        assertEq(
            creator.balance - creatorBalanceBefore,
            expectedCreatorFee,
            "Creator should receive 95%"
        );

        // Verify 5% accumulated in projectFees (not lost)
        uint256 expectedProjectFee = (mintCost * 5) / 100;
        assertEq(
            factoryNoRouter.projectFees(),
            expectedProjectFee,
            "Project fees should accumulate 5%"
        );
    }
}
