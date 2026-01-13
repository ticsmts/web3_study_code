// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {OptionToken} from "../src/OptionToken.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

/**
 * @title OptionTokenTest
 * @notice 全抵押欧式看涨期权 Token 测试套件
 */
contract OptionTokenTest is Test {
    OptionToken public option;
    MockUSDT public usdt;

    address public owner;
    address public alice;
    address public bob;

    uint256 public constant STRIKE_PRICE = 2000e6; // 2000 USDT per ETH
    uint256 public expiry; // 到期时间

    event Issue(
        address indexed issuer,
        uint256 ethDeposited,
        uint256 optionsMinted
    );
    event Exercise(address indexed user, uint256 amountWei, uint256 usdtPaid);
    event Reclaim(address indexed issuer, uint256 ethReclaimed);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // 设置到期时间为 7 天后
        expiry = block.timestamp + 7 days;

        // 部署 MockUSDT
        usdt = new MockUSDT();

        // 以 owner 身份部署 OptionToken
        vm.prank(owner);
        option = new OptionToken(address(usdt), STRIKE_PRICE, expiry, owner);

        // 给 owner 一些 ETH
        vm.deal(owner, 100 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    // ========================
    // Test 1: Issue 铸造测试
    // ========================

    /**
     * @notice 测试 issue() 1:1 铸造期权
     */
    function test_Issue_MintsOptions1to1() public {
        uint256 depositAmount = 10 ether;

        vm.prank(owner);
        option.issue{value: depositAmount}();

        // 断言
        assertEq(
            option.totalSupply(),
            depositAmount,
            "totalSupply should equal deposit"
        );
        assertEq(
            option.balanceOf(owner),
            depositAmount,
            "owner balance should equal deposit"
        );
        assertEq(
            address(option).balance,
            depositAmount,
            "contract ETH balance should equal deposit"
        );
    }

    /**
     * @notice 测试非 issuer 无法调用 issue()
     */
    function test_Issue_RevertsIfNotIssuer() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotIssuer()"));
        option.issue{value: 1 ether}();
    }

    /**
     * @notice 测试多次 issue 累积
     */
    function test_Issue_MultipleTimes() public {
        vm.startPrank(owner);
        option.issue{value: 3 ether}();
        option.issue{value: 2 ether}();
        vm.stopPrank();

        assertEq(option.totalSupply(), 5 ether);
        assertEq(option.balanceOf(owner), 5 ether);
        assertEq(address(option).balance, 5 ether);
    }

    // ========================
    // Test 2: 到期前无法行权
    // ========================

    /**
     * @notice 测试到期前无法行权
     */
    function test_CannotExercise_BeforeExpiry() public {
        // issuer issue 1 ether
        vm.prank(owner);
        option.issue{value: 1 ether}();

        // 转 0.5 ether 的 oETHC 给 alice
        vm.prank(owner);
        option.transfer(alice, 0.5 ether);

        // 给 alice mint 足够 USDT 并 approve
        usdt.mint(alice, 2000e6);
        vm.prank(alice);
        usdt.approve(address(option), 2000e6);

        // 在 expiry 之前调用 exercise 应 revert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotInExerciseWindow()"));
        option.exercise(0.5 ether);
    }

    // ========================
    // Test 3: 到期窗口内行权成功
    // ========================

    /**
     * @notice 测试到期日当天行权成功
     */
    function test_Exercise_OnExpiryWindow_Success() public {
        uint256 exerciseAmount = 1 ether;
        uint256 expectedUsdt = 2000e6; // 1 ETH * 2000 USDT/ETH

        // issuer issue 1 ether
        vm.prank(owner);
        option.issue{value: exerciseAmount}();

        // 转 1 ether oETHC 给 alice
        vm.prank(owner);
        option.transfer(alice, exerciseAmount);

        // 到期日当天
        vm.warp(expiry);

        // 给 alice mint USDT 并 approve
        usdt.mint(alice, expectedUsdt);
        vm.prank(alice);
        usdt.approve(address(option), expectedUsdt);

        // 记录行权前状态
        uint256 aliceEthBefore = alice.balance;
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);

        // alice 调用 exercise
        vm.prank(alice);
        option.exercise(exerciseAmount);

        // 断言
        assertEq(option.balanceOf(alice), 0, "alice oETHC balance should be 0");
        assertEq(option.totalSupply(), 0, "totalSupply should be 0");
        assertEq(
            alice.balance - aliceEthBefore,
            exerciseAmount,
            "alice should receive 1 ether"
        );
        assertEq(
            usdt.balanceOf(owner) - ownerUsdtBefore,
            expectedUsdt,
            "issuer should receive 2000 USDT"
        );
        assertEq(
            address(option).balance,
            0,
            "contract ETH balance should be 0"
        );
    }

    // ========================
    // Test 4: 部分行权
    // ========================

    /**
     * @notice 测试部分行权
     */
    function test_Exercise_PartialAmount_Works() public {
        // issuer issue 2 ether
        vm.prank(owner);
        option.issue{value: 2 ether}();

        // 转 1.5 ether 给 alice
        vm.prank(owner);
        option.transfer(alice, 1.5 ether);

        // warp 到 expiry
        vm.warp(expiry);

        // 行权 0.4 ether
        uint256 exerciseAmount = 0.4 ether;
        uint256 expectedUsdt = (exerciseAmount * STRIKE_PRICE) / 1e18; // 0.4 * 2000 = 800 USDT = 800e6

        assertEq(expectedUsdt, 800e6, "Expected USDT should be 800e6");

        // 给 alice mint USDT 并 approve
        usdt.mint(alice, expectedUsdt);
        vm.prank(alice);
        usdt.approve(address(option), expectedUsdt);

        // 记录行权前状态
        uint256 aliceEthBefore = alice.balance;
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);

        // 行权
        vm.prank(alice);
        option.exercise(exerciseAmount);

        // 断言 alice 剩余 oETHC == 1.1 ether（精确）
        assertEq(
            option.balanceOf(alice),
            1.1 ether,
            "alice should have 1.1 ether oETHC remaining"
        );

        // 断言支付 USDT = 800e6
        assertEq(
            usdt.balanceOf(owner) - ownerUsdtBefore,
            800e6,
            "issuer should receive 800e6 USDT"
        );

        // 断言 alice 收到 0.4 ether
        assertEq(
            alice.balance - aliceEthBefore,
            exerciseAmount,
            "alice should receive 0.4 ether"
        );
    }

    // ========================
    // Test 5: 窗口结束后无法行权
    // ========================

    /**
     * @notice 测试窗口结束后无法行权
     */
    function test_CannotExercise_AfterWindow() public {
        // issuer issue 1 ether
        vm.prank(owner);
        option.issue{value: 1 ether}();

        // 转给 alice
        vm.prank(owner);
        option.transfer(alice, 1 ether);

        // warp 到 expiry + 1 days（窗口结束）
        vm.warp(expiry + 1 days);

        // 给 alice mint USDT 并 approve
        usdt.mint(alice, 2000e6);
        vm.prank(alice);
        usdt.approve(address(option), 2000e6);

        // exercise 应 revert
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotInExerciseWindow()"));
        option.exercise(1 ether);
    }

    // ========================
    // Test 6: 赎回测试
    // ========================

    /**
     * @notice 测试 reclaimExpired 权限和时间限制
     */
    function test_ReclaimExpired_OnlyIssuer_AndAfterWindow() public {
        // issuer issue 3 ether
        vm.prank(owner);
        option.issue{value: 3 ether}();

        // 非 issuer 调用 reclaimExpired() revert（即使时间到了）
        vm.warp(expiry + 1 days);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotIssuer()"));
        option.reclaimExpired();

        // 在窗口结束前，issuer 也不能赎回
        vm.warp(expiry); // 回到窗口开始
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("NotExpired()"));
        option.reclaimExpired();

        // warp 到 expiry + 1 days（窗口结束）
        vm.warp(expiry + 1 days);

        // 记录赎回前状态
        uint256 ownerEthBefore = owner.balance;

        // issuer 调用 reclaimExpired 成功
        vm.prank(owner);
        option.reclaimExpired();

        // 断言 issuer ETH 增加 3 ether
        assertEq(
            owner.balance - ownerEthBefore,
            3 ether,
            "owner should receive 3 ether"
        );

        // 断言合约 ETH 变 0
        assertEq(
            address(option).balance,
            0,
            "contract ETH balance should be 0"
        );
    }

    // ========================
    // Test 7: ERC20 基本功能测试
    // ========================

    /**
     * @notice 测试 ERC20 transfer/approve/transferFrom
     */
    function test_ERC20_TransferApproveTransferFrom_Works() public {
        // issuer issue 5 ether
        vm.prank(owner);
        option.issue{value: 5 ether}();

        // issuer approve bob 2 ether
        vm.prank(owner);
        option.approve(bob, 2 ether);
        assertEq(
            option.allowance(owner, bob),
            2 ether,
            "allowance should be 2 ether"
        );

        // bob transferFrom issuer -> alice 1 ether
        vm.prank(bob);
        option.transferFrom(owner, alice, 1 ether);

        // 断言 allowance 减少到 1 ether
        assertEq(
            option.allowance(owner, bob),
            1 ether,
            "allowance should decrease to 1 ether"
        );

        // 断言余额变化正确
        assertEq(option.balanceOf(owner), 4 ether, "owner should have 4 ether");
        assertEq(option.balanceOf(alice), 1 ether, "alice should have 1 ether");
        assertEq(option.balanceOf(bob), 0, "bob should have 0");

        // 测试直接 transfer
        vm.prank(owner);
        option.transfer(bob, 0.5 ether);
        assertEq(
            option.balanceOf(owner),
            3.5 ether,
            "owner should have 3.5 ether"
        );
        assertEq(option.balanceOf(bob), 0.5 ether, "bob should have 0.5 ether");
    }

    // ========================
    // 额外测试
    // ========================

    /**
     * @notice 测试行权时 USDT 授权不足
     */
    function test_Exercise_RevertsOnInsufficientAllowance() public {
        vm.prank(owner);
        option.issue{value: 1 ether}();

        vm.prank(owner);
        option.transfer(alice, 1 ether);

        vm.warp(expiry);

        // 给 alice mint USDT 但不 approve
        usdt.mint(alice, 2000e6);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("InsufficientAllowance()"));
        option.exercise(1 ether);
    }

    /**
     * @notice 测试行权时余额不足
     */
    function test_Exercise_RevertsOnInsufficientBalance() public {
        vm.prank(owner);
        option.issue{value: 1 ether}();

        vm.prank(owner);
        option.transfer(alice, 0.5 ether);

        vm.warp(expiry);

        usdt.mint(alice, 2000e6);
        vm.prank(alice);
        usdt.approve(address(option), 2000e6);

        // alice 尝试行权超过她持有的数量
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBalance()"));
        option.exercise(1 ether);
    }

    /**
     * @notice 测试视图函数
     */
    function test_ViewFunctions() public view {
        // 期权未到期
        assertFalse(option.isInExerciseWindow());
        assertFalse(option.isExpired());

        // 测试 calculateUsdtPayment
        uint256 payment = option.calculateUsdtPayment(0.5 ether);
        assertEq(payment, 1000e6, "0.5 ETH should cost 1000 USDT");

        payment = option.calculateUsdtPayment(1 ether);
        assertEq(payment, 2000e6, "1 ETH should cost 2000 USDT");

        payment = option.calculateUsdtPayment(0.001 ether);
        assertEq(payment, 2e6, "0.001 ETH should cost 2 USDT");
    }

    /**
     * @notice 测试到期窗口边界
     */
    function test_ExerciseWindow_Boundaries() public {
        vm.prank(owner);
        option.issue{value: 1 ether}();

        vm.prank(owner);
        option.transfer(alice, 1 ether);

        usdt.mint(alice, 4000e6);
        vm.prank(alice);
        usdt.approve(address(option), 4000e6);

        // 刚好在 expiry - 1 秒，不能行权
        vm.warp(expiry - 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("NotInExerciseWindow()"));
        option.exercise(0.5 ether);

        // 刚好在 expiry，可以行权
        vm.warp(expiry);
        vm.prank(alice);
        option.exercise(0.5 ether);
        assertEq(option.balanceOf(alice), 0.5 ether);

        // 刚好在 expiry + 1 days - 1 秒，还可以行权
        vm.warp(expiry + 1 days - 1);
        vm.prank(alice);
        option.exercise(0.5 ether);
        assertEq(option.balanceOf(alice), 0);
    }

    /**
     * @notice 测试事件发射
     */
    function test_Events() public {
        // 测试 Issue 事件
        vm.expectEmit(true, false, false, true);
        emit Issue(owner, 1 ether, 1 ether);
        vm.prank(owner);
        option.issue{value: 1 ether}();

        vm.prank(owner);
        option.transfer(alice, 1 ether);

        vm.warp(expiry);

        usdt.mint(alice, 2000e6);
        vm.prank(alice);
        usdt.approve(address(option), 2000e6);

        // 测试 Exercise 事件
        vm.expectEmit(true, false, false, true);
        emit Exercise(alice, 1 ether, 2000e6);
        vm.prank(alice);
        option.exercise(1 ether);
    }

    // ================================================================
    // 资金流控制测试：存入、行权、赎回
    // 运行命令: forge test --match-contract OptionTokenTest --match-test FundFlow -vvv
    // ================================================================

    /**
     * @notice 资金流测试 1: Issue（存入）资金流详解
     * @dev 验证项目方存入 ETH 后的资金变化
     *
     * 资金流向:
     * [Issuer] ---(ETH)---> [OptionToken Contract]
     * [OptionToken Contract] ---(oETHC Token)---> [Issuer]
     */
    function test_FundFlow_Issue_Deposit() public {
        console.log("========== FUND FLOW: ISSUE (DEPOSIT) ==========");

        uint256 depositAmount = 5 ether;

        // ===== 存入前状态 =====
        uint256 issuerEthBefore = owner.balance;
        uint256 contractEthBefore = address(option).balance;
        uint256 issuerTokenBefore = option.balanceOf(owner);
        uint256 totalSupplyBefore = option.totalSupply();

        console.log("--- Before Issue ---");
        console.log("Issuer ETH balance:", issuerEthBefore / 1e18, "ETH");
        console.log("Contract ETH balance:", contractEthBefore / 1e18, "ETH");
        console.log("Issuer oETHC balance:", issuerTokenBefore / 1e18, "oETHC");
        console.log("Total supply:", totalSupplyBefore / 1e18, "oETHC");

        // ===== 执行存入 =====
        vm.prank(owner);
        option.issue{value: depositAmount}();

        // ===== 存入后状态 =====
        uint256 issuerEthAfter = owner.balance;
        uint256 contractEthAfter = address(option).balance;
        uint256 issuerTokenAfter = option.balanceOf(owner);
        uint256 totalSupplyAfter = option.totalSupply();

        console.log("");
        console.log("--- After Issue (deposited 5 ETH) ---");
        console.log("Issuer ETH balance:", issuerEthAfter / 1e18, "ETH (-5)");
        console.log(
            "Contract ETH balance:",
            contractEthAfter / 1e18,
            "ETH (+5)"
        );
        console.log(
            "Issuer oETHC balance:",
            issuerTokenAfter / 1e18,
            "oETHC (+5)"
        );
        console.log("Total supply:", totalSupplyAfter / 1e18, "oETHC (+5)");

        // ===== 资金流验证 =====
        console.log("");
        console.log("--- Fund Flow Verification ---");
        assertEq(
            issuerEthBefore - issuerEthAfter,
            depositAmount,
            "Issuer should spend 5 ETH"
        );
        assertEq(
            contractEthAfter - contractEthBefore,
            depositAmount,
            "Contract should receive 5 ETH"
        );
        assertEq(
            issuerTokenAfter - issuerTokenBefore,
            depositAmount,
            "Issuer should receive 5 oETHC"
        );
        assertEq(
            totalSupplyAfter - totalSupplyBefore,
            depositAmount,
            "Total supply should increase by 5"
        );

        // 核心不变量: 合约 ETH 余额 >= totalSupply
        assertGe(
            address(option).balance,
            option.totalSupply(),
            "ETH collateral invariant"
        );
        console.log("All fund flow assertions passed!");
    }

    /**
     * @notice 资金流测试 2: Exercise（行权）资金流详解
     * @dev 验证用户行权时的三方资金变化
     *
     * 资金流向:
     * [User] ---(USDT)---> [Issuer]           (支付行权价)
     * [User] ---(oETHC)---> [Burn/销毁]        (销毁期权Token)
     * [OptionToken Contract] ---(ETH)---> [User]  (获得标的资产)
     */
    function test_FundFlow_Exercise_Complete() public {
        console.log("========== FUND FLOW: EXERCISE ==========");

        uint256 depositAmount = 2 ether;
        uint256 exerciseAmount = 1.5 ether;
        uint256 expectedUsdtPayment = (exerciseAmount * STRIKE_PRICE) / 1e18;
        // 1.5 * 2000e6 / 1e18 = 3000e6 = 3000 USDT

        // ===== 准备阶段 =====
        // 1. Issuer 存入 ETH
        vm.prank(owner);
        option.issue{value: depositAmount}();

        // 2. 转移期权给用户
        vm.prank(owner);
        option.transfer(alice, exerciseAmount);

        // 3. 给用户 USDT 并授权
        usdt.mint(alice, expectedUsdtPayment);
        vm.prank(alice);
        usdt.approve(address(option), expectedUsdtPayment);

        // 4. 进入行权窗口
        vm.warp(expiry);

        // ===== 行权前状态 =====
        uint256 aliceEthBefore = alice.balance;
        uint256 aliceUsdtBefore = usdt.balanceOf(alice);
        uint256 aliceTokenBefore = option.balanceOf(alice);
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        uint256 contractEthBefore = address(option).balance;
        uint256 totalSupplyBefore = option.totalSupply();

        console.log("--- Before Exercise ---");
        console.log("Alice ETH:", aliceEthBefore / 1e18, "ETH");
        console.log("Alice USDT:", aliceUsdtBefore / 1e6, "USDT");
        console.log("Alice oETHC:", aliceTokenBefore / 1e18, "oETHC");
        console.log("Owner USDT:", ownerUsdtBefore / 1e6, "USDT");
        console.log("Contract ETH:", contractEthBefore / 1e18, "ETH");
        console.log("Total supply:", totalSupplyBefore / 1e18, "oETHC");

        // ===== 执行行权 =====
        console.log("");
        console.log("--- Executing Exercise: 1.5 oETHC ---");
        console.log(
            "USDT to pay: (1.5 * 2000e6) / 1e18 =",
            expectedUsdtPayment / 1e6,
            "USDT"
        );

        vm.prank(alice);
        option.exercise(exerciseAmount);

        // ===== 行权后状态 =====
        uint256 aliceEthAfter = alice.balance;
        uint256 aliceUsdtAfter = usdt.balanceOf(alice);
        uint256 aliceTokenAfter = option.balanceOf(alice);
        uint256 ownerUsdtAfter = usdt.balanceOf(owner);
        uint256 contractEthAfter = address(option).balance;
        uint256 totalSupplyAfter = option.totalSupply();

        console.log("");
        console.log("--- After Exercise ---");
        console.log("Alice ETH:", aliceEthAfter / 1e18, "ETH (+1.5)");
        console.log("Alice USDT:", aliceUsdtAfter / 1e6, "USDT (-3000)");
        console.log(
            "Alice oETHC:",
            aliceTokenAfter / 1e18,
            "oETHC (-1.5, burned)"
        );
        console.log("Owner USDT:", ownerUsdtAfter / 1e6, "USDT (+3000)");
        console.log("Contract ETH:", contractEthAfter / 1e18, "ETH (-1.5)");
        console.log("Total supply:", totalSupplyAfter / 1e18, "oETHC (-1.5)");

        // ===== 资金流验证 =====
        console.log("");
        console.log("--- Fund Flow Verification ---");

        // Alice: +1.5 ETH, -3000 USDT, -1.5 oETHC
        assertEq(
            aliceEthAfter - aliceEthBefore,
            exerciseAmount,
            "Alice should receive 1.5 ETH"
        );
        assertEq(
            aliceUsdtBefore - aliceUsdtAfter,
            expectedUsdtPayment,
            "Alice should pay 3000 USDT"
        );
        assertEq(
            aliceTokenBefore - aliceTokenAfter,
            exerciseAmount,
            "Alice oETHC should decrease by 1.5"
        );

        // Owner: +3000 USDT
        assertEq(
            ownerUsdtAfter - ownerUsdtBefore,
            expectedUsdtPayment,
            "Owner should receive 3000 USDT"
        );

        // Contract: -1.5 ETH
        assertEq(
            contractEthBefore - contractEthAfter,
            exerciseAmount,
            "Contract ETH should decrease by 1.5"
        );

        // Total supply: -1.5 (burned)
        assertEq(
            totalSupplyBefore - totalSupplyAfter,
            exerciseAmount,
            "Total supply should decrease by 1.5"
        );

        // 核心不变量
        assertGe(
            address(option).balance,
            option.totalSupply(),
            "ETH collateral invariant"
        );
        console.log("All fund flow assertions passed!");
    }

    /**
     * @notice 资金流测试 3: Reclaim（赎回）资金流详解
     * @dev 验证到期后项目方赎回剩余 ETH
     *
     * 资金流向:
     * [OptionToken Contract] ---(remaining ETH)---> [Issuer]
     */
    function test_FundFlow_Reclaim_Expired() public {
        console.log("========== FUND FLOW: RECLAIM EXPIRED ==========");

        uint256 depositAmount = 3 ether;
        uint256 aliceExerciseAmount = 1 ether; // Alice 只行权 1 ETH

        // ===== 准备阶段 =====
        // 1. Issuer 存入 3 ETH
        vm.prank(owner);
        option.issue{value: depositAmount}();

        // 2. 转移 1 ETH 期权给 Alice
        vm.prank(owner);
        option.transfer(alice, aliceExerciseAmount);

        // 3. 进入行权窗口，Alice 行权 1 ETH
        vm.warp(expiry);
        uint256 aliceUsdt = (aliceExerciseAmount * STRIKE_PRICE) / 1e18; // 2000 USDT
        usdt.mint(alice, aliceUsdt);
        vm.prank(alice);
        usdt.approve(address(option), aliceUsdt);
        vm.prank(alice);
        option.exercise(aliceExerciseAmount);

        console.log("--- After Alice exercised 1 ETH ---");
        console.log(
            "Contract remaining ETH:",
            address(option).balance / 1e18,
            "ETH"
        );
        console.log(
            "Remaining total supply:",
            option.totalSupply() / 1e18,
            "oETHC"
        );

        // 4. 窗口结束
        vm.warp(expiry + 1 days);

        // ===== 赎回前状态 =====
        uint256 ownerEthBefore = owner.balance;
        uint256 contractEthBefore = address(option).balance;

        console.log("");
        console.log("--- Before Reclaim (window expired) ---");
        console.log("Owner ETH:", ownerEthBefore / 1e18, "ETH");
        console.log(
            "Contract ETH (to reclaim):",
            contractEthBefore / 1e18,
            "ETH"
        );

        // ===== 执行赎回 =====
        console.log("");
        console.log("--- Executing Reclaim ---");

        vm.prank(owner);
        option.reclaimExpired();

        // ===== 赎回后状态 =====
        uint256 ownerEthAfter = owner.balance;
        uint256 contractEthAfter = address(option).balance;

        console.log("");
        console.log("--- After Reclaim ---");
        console.log("Owner ETH:", ownerEthAfter / 1e18, "ETH (+2)");
        console.log("Contract ETH:", contractEthAfter / 1e18, "ETH (empty)");

        // ===== 资金流验证 =====
        console.log("");
        console.log("--- Fund Flow Verification ---");

        // 应该赎回 2 ETH (3 - 1 被行权)
        uint256 expectedReclaim = depositAmount - aliceExerciseAmount;
        assertEq(
            ownerEthAfter - ownerEthBefore,
            expectedReclaim,
            "Owner should receive 2 ETH"
        );
        assertEq(contractEthAfter, 0, "Contract should be empty");

        console.log("Expected reclaim: 3 - 1 =", expectedReclaim / 1e18, "ETH");
        console.log("All fund flow assertions passed!");
    }

    /**
     * @notice 资金流测试 4: 完整生命周期演示
     * @dev 从发行到到期的完整资金流
     */
    function test_FundFlow_FullLifecycle() public {
        console.log("========== FUND FLOW: FULL LIFECYCLE ==========");

        // ===== 阶段 1: 发行 =====
        console.log("");
        console.log("[Phase 1] ISSUE - Issuer deposits 10 ETH");
        console.log("-------------------------------------------");

        vm.prank(owner);
        option.issue{value: 10 ether}();

        console.log("Contract ETH:", address(option).balance / 1e18, "ETH");
        console.log("Total oETHC:", option.totalSupply() / 1e18);
        console.log("Issuer oETHC:", option.balanceOf(owner) / 1e18);

        // ===== 阶段 2: 分发期权 =====
        console.log("");
        console.log("[Phase 2] DISTRIBUTE - Transfer options to users");
        console.log("------------------------------------------------");

        vm.startPrank(owner);
        option.transfer(alice, 4 ether); // Alice 获得 4 oETHC
        option.transfer(bob, 3 ether); // Bob 获得 3 oETHC
        vm.stopPrank();

        console.log("Alice oETHC:", option.balanceOf(alice) / 1e18);
        console.log("Bob oETHC:", option.balanceOf(bob) / 1e18);
        console.log("Owner oETHC:", option.balanceOf(owner) / 1e18);

        // ===== 阶段 3: 行权窗口 =====
        console.log("");
        console.log("[Phase 3] EXERCISE WINDOW");
        console.log("--------------------------");

        vm.warp(expiry);

        // Alice 行权 2 ETH
        uint256 aliceUsdt = (2 ether * STRIKE_PRICE) / 1e18; // 4000 USDT
        usdt.mint(alice, aliceUsdt);
        vm.prank(alice);
        usdt.approve(address(option), aliceUsdt);

        uint256 aliceEthBefore = alice.balance;
        vm.prank(alice);
        option.exercise(2 ether);

        console.log("Alice exercised 2 oETHC:");
        console.log("  - Paid:", aliceUsdt / 1e6, "USDT");
        console.log(
            "  - Received:",
            (alice.balance - aliceEthBefore) / 1e18,
            "ETH"
        );
        console.log("  - Remaining oETHC:", option.balanceOf(alice) / 1e18);

        // Bob 行权全部 3 ETH
        uint256 bobUsdt = (3 ether * STRIKE_PRICE) / 1e18; // 6000 USDT
        usdt.mint(bob, bobUsdt);
        vm.prank(bob);
        usdt.approve(address(option), bobUsdt);

        uint256 bobEthBefore = bob.balance;
        vm.prank(bob);
        option.exercise(3 ether);

        console.log("");
        console.log("Bob exercised 3 oETHC:");
        console.log("  - Paid:", bobUsdt / 1e6, "USDT");
        console.log(
            "  - Received:",
            (bob.balance - bobEthBefore) / 1e18,
            "ETH"
        );
        console.log("  - Remaining oETHC:", option.balanceOf(bob) / 1e18);

        // ===== 阶段 4: 窗口结束，赎回 =====
        console.log("");
        console.log("[Phase 4] EXPIRED - Reclaim remaining ETH");
        console.log("-----------------------------------------");

        vm.warp(expiry + 1 days);

        console.log(
            "Contract ETH before reclaim:",
            address(option).balance / 1e18,
            "ETH"
        );
        console.log("Unexercised options:");
        console.log(
            "  - Alice:",
            option.balanceOf(alice) / 1e18,
            "oETHC (expired worthless)"
        );
        console.log(
            "  - Owner:",
            option.balanceOf(owner) / 1e18,
            "oETHC (expired worthless)"
        );

        uint256 ownerEthBefore = owner.balance;
        vm.prank(owner);
        option.reclaimExpired();

        console.log("");
        console.log("After reclaim:");
        console.log(
            "  - Owner received:",
            (owner.balance - ownerEthBefore) / 1e18,
            "ETH"
        );
        console.log("  - Contract ETH:", address(option).balance / 1e18, "ETH");

        // ===== 最终验证 =====
        console.log("");
        console.log("[SUMMARY]");
        console.log("=========");
        console.log("Total deposited: 10 ETH");
        console.log("Total exercised: 5 ETH (Alice 2 + Bob 3)");
        console.log("Total reclaimed: 5 ETH");
        console.log(
            "Issuer USDT received:",
            usdt.balanceOf(owner) / 1e6,
            "USDT"
        );

        // 验证
        assertEq(address(option).balance, 0, "Contract should be empty");
        assertEq(
            usdt.balanceOf(owner),
            10000e6,
            "Owner should have 10000 USDT"
        );
    }

    /**
     * @notice 资金流测试 5: 单位换算验证
     * @dev 验证 ETH (18 decimals) 和 USDT (6 decimals) 的换算
     */
    function test_FundFlow_UnitConversion() public {
        console.log("========== FUND FLOW: UNIT CONVERSION ==========");

        // 测试不同金额的换算
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 1 ether; // 1 ETH
        amounts[1] = 0.5 ether; // 0.5 ETH
        amounts[2] = 0.001 ether; // 0.001 ETH
        amounts[3] = 0.1 ether; // 0.1 ETH
        amounts[4] = 2.5 ether; // 2.5 ETH

        console.log("Strike Price: 2000 USDT/ETH");
        console.log("");
        console.log(
            "Amount (ETH) | Amount (wei) | USDT Payment | USDT (units)"
        );
        console.log(
            "-------------|--------------|--------------|-------------"
        );

        for (uint i = 0; i < amounts.length; i++) {
            uint256 amountWei = amounts[i];
            uint256 usdtPayment = option.calculateUsdtPayment(amountWei);

            // 格式化输出 (console.log 最多支持 4 个参数)
            console.log(
                "Amount:",
                amountWei / 1e18,
                "ETH -> USDT:",
                usdtPayment / 1e6
            );
        }

        // 验证计算公式
        console.log("");
        console.log("Formula: usdtToPay = amountWei * strikePrice / 1e18");
        console.log("");
        console.log("Example: 0.4 ETH");
        console.log("  amountWei = 0.4 * 1e18 = 4e17");
        console.log("  strikePrice = 2000 * 1e6 = 2e9");
        console.log("  usdtToPay = 4e17 * 2e9 / 1e18 = 8e8 = 800e6 = 800 USDT");

        uint256 testAmount = 0.4 ether;
        uint256 testUsdt = option.calculateUsdtPayment(testAmount);
        assertEq(testUsdt, 800e6, "0.4 ETH should cost 800 USDT");
    }
}
