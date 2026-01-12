// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {RebaseDeflationaryToken} from "../src/RebaseDeflationaryToken.sol";

/**
 * @title RebaseDeflationaryToken 单元测试
 * @notice 使用 Foundry 测试框架
 */
contract RebaseDeflationaryTokenTest is Test {
    RebaseDeflationaryToken public token;

    address public deployer = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public spender = makeAddr("spender");

    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 1e18;
    uint256 public constant ONE_YEAR = 365 days;

    function setUp() public {
        token = new RebaseDeflationaryToken();
    }

    // ============ 1. 初始化测试 ============

    /**
     * @dev 测试: totalSupply == INITIAL_SUPPLY
     */
    function test_InitialTotalSupply() public view {
        assertEq(
            token.totalSupply(),
            INITIAL_SUPPLY,
            "Initial totalSupply should be INITIAL_SUPPLY"
        );
    }

    /**
     * @dev 测试: deployer balance == INITIAL_SUPPLY
     */
    function test_DeployerBalance() public view {
        assertEq(
            token.balanceOf(deployer),
            INITIAL_SUPPLY,
            "Deployer should have INITIAL_SUPPLY"
        );
    }

    /**
     * @dev 测试: TOTAL_GONS % INITIAL_SUPPLY == 0
     * 这确保初始 gonsPerFragment 是整数，减少舍入误差
     */
    function test_TotalGonsDivisibility() public view {
        uint256 totalGons = token.TOTAL_GONS();
        assertEq(
            totalGons % INITIAL_SUPPLY,
            0,
            "TOTAL_GONS should be divisible by INITIAL_SUPPLY"
        );
    }

    /**
     * @dev 测试: 基本代币元数据
     */
    function test_TokenMetadata() public view {
        assertEq(token.name(), "Rebase Deflationary Token");
        assertEq(token.symbol(), "RDFT");
        assertEq(token.decimals(), 18);
    }

    /**
     * @dev 测试: 初始 gonsPerFragment 正确
     */
    function test_InitialGonsPerFragment() public view {
        uint256 expectedGonsPerFragment = token.TOTAL_GONS() / INITIAL_SUPPLY;
        assertEq(
            token.gonsPerFragment(),
            expectedGonsPerFragment,
            "Initial gonsPerFragment should be TOTAL_GONS / INITIAL_SUPPLY"
        );
    }

    // ============ 2. 转账正确性测试 (Rebase 前) ============

    /**
     * @dev 测试: deployer -> alice 转 100e18
     */
    function test_TransferBeforeRebase() public {
        uint256 transferAmount = 100e18;

        uint256 deployerBalanceBefore = token.balanceOf(deployer);

        token.transfer(alice, transferAmount);

        assertEq(
            token.balanceOf(alice),
            transferAmount,
            "Alice should receive 100e18"
        );
        assertEq(
            token.balanceOf(deployer),
            deployerBalanceBefore - transferAmount,
            "Deployer balance should decrease"
        );
    }

    /**
     * @dev 测试: 转账后 gons 余额正确
     */
    function test_TransferUpdatesGonBalances() public {
        uint256 transferAmount = 100e18;
        uint256 expectedGonValue = transferAmount * token.gonsPerFragment();

        uint256 deployerGonsBefore = token.gonBalanceOf(deployer);

        token.transfer(alice, transferAmount);

        assertEq(
            token.gonBalanceOf(alice),
            expectedGonValue,
            "Alice gons should be transferAmount * gonsPerFragment"
        );
        assertEq(
            token.gonBalanceOf(deployer),
            deployerGonsBefore - expectedGonValue,
            "Deployer gons should decrease"
        );
    }

    /**
     * @dev 测试: 余额不足时转账失败
     */
    function test_TransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 1e18);
    }

    /**
     * @dev 测试: 不能转账到零地址
     */
    function test_TransferToZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseDeflationaryToken.ERC20InvalidReceiver.selector,
                address(0)
            )
        );
        token.transfer(address(0), 100e18);
    }

    // ============ 3. 跨年 Rebase 测试 ============

    /**
     * @dev 测试: warp +365 days 后 rebase()
     * totalSupply 约等于 old * 0.99
     */
    function test_RebaseAfterOneYear() public {
        uint256 oldSupply = token.totalSupply();

        // 跳过一年
        vm.warp(block.timestamp + ONE_YEAR);

        // 调用 rebase
        token.rebase();

        uint256 newSupply = token.totalSupply();
        uint256 expectedSupply = (oldSupply * 99) / 100;

        // 由于两次除法的舍入，可能有微小差异
        // 使用 assertApproxEqAbs 允许 1 wei 的误差
        assertApproxEqAbs(
            newSupply,
            expectedSupply,
            1,
            "New supply should be ~99% of old supply"
        );
    }

    /**
     * @dev 测试: rebase 后所有账户余额都减少约 1%
     */
    function test_RebaseReducesAllBalances() public {
        // 先分配一些代币
        token.transfer(alice, 10_000_000e18); // 10M
        token.transfer(bob, 5_000_000e18); // 5M

        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 deployerBalanceBefore = token.balanceOf(deployer);

        // 跳过一年并 rebase
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 bobBalanceAfter = token.balanceOf(bob);
        uint256 deployerBalanceAfter = token.balanceOf(deployer);

        // 检查余额减少约 1%
        assertApproxEqRel(
            aliceBalanceAfter,
            (aliceBalanceBefore * 99) / 100,
            1e14,
            "Alice balance should be ~99%"
        );
        assertApproxEqRel(
            bobBalanceAfter,
            (bobBalanceBefore * 99) / 100,
            1e14,
            "Bob balance should be ~99%"
        );
        assertApproxEqRel(
            deployerBalanceAfter,
            (deployerBalanceBefore * 99) / 100,
            1e14,
            "Deployer balance should be ~99%"
        );
    }

    /**
     * @dev 测试: rebase 后持仓占比不变
     */
    function test_RebasePreservesOwnershipRatio() public {
        // 分配代币
        token.transfer(alice, 10_000_000e18); // 10%

        uint256 totalSupplyBefore = token.totalSupply();
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // 计算 Alice 的持仓占比 (放大 1e18 避免精度损失)
        uint256 aliceRatioBefore = (aliceBalanceBefore * 1e18) /
            totalSupplyBefore;

        // 跳过一年并 rebase
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 totalSupplyAfter = token.totalSupply();
        uint256 aliceBalanceAfter = token.balanceOf(alice);
        uint256 aliceRatioAfter = (aliceBalanceAfter * 1e18) / totalSupplyAfter;

        // 持仓占比应该保持一致 (允许极小误差)
        assertApproxEqAbs(
            aliceRatioAfter,
            aliceRatioBefore,
            1e10,
            "Alice ownership ratio should be preserved"
        );
    }

    /**
     * @dev 测试: rebase 不改变 gons 余额
     */
    function test_RebaseDoesNotChangeGonBalances() public {
        token.transfer(alice, 10_000_000e18);

        uint256 aliceGonsBefore = token.gonBalanceOf(alice);
        uint256 deployerGonsBefore = token.gonBalanceOf(deployer);

        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 aliceGonsAfter = token.gonBalanceOf(alice);
        uint256 deployerGonsAfter = token.gonBalanceOf(deployer);

        assertEq(
            aliceGonsAfter,
            aliceGonsBefore,
            "Alice gons should not change after rebase"
        );
        assertEq(
            deployerGonsAfter,
            deployerGonsBefore,
            "Deployer gons should not change after rebase"
        );
    }

    /**
     * @dev 测试: rebase 事件正确发出
     */
    function test_RebaseEmitsEvent() public {
        uint256 oldSupply = token.totalSupply();
        uint256 rebaseTime = block.timestamp + ONE_YEAR;

        vm.warp(rebaseTime);

        vm.expectEmit(true, false, false, true);
        // epoch = 1, oldSupply, newSupply, timestamp
        emit RebaseDeflationaryToken.Rebase(
            1,
            oldSupply,
            (oldSupply * 99) / 100,
            rebaseTime
        );

        token.rebase();
    }

    // ============ 4. 一年内不能二次 Rebase ============

    /**
     * @dev 测试: rebase 后立刻再次调用应 revert
     */
    function test_CannotRebaseTwiceInOneYear() public {
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        // 立刻再次调用应该失败
        vm.expectRevert();
        token.rebase();
    }

    /**
     * @dev 测试: rebase 后等待不足一年也应失败
     */
    function test_CannotRebaseBeforeInterval() public {
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        // 等待 364 天
        vm.warp(block.timestamp + 364 days);

        vm.expectRevert();
        token.rebase();
    }

    /**
     * @dev 测试: 两年后可以 rebase 两次
     */
    function test_CanRebaseAfterAnotherYear() public {
        // 第一次 rebase
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();
        assertEq(token.epoch(), 1);

        // 第二次 rebase
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();
        assertEq(token.epoch(), 2);
    }

    // ============ 5. Rebase 后再转账 ============

    /**
     * @dev 测试: rebase 后 alice -> bob 转 10e18
     * bob balance 应增加 10e18 (fragments 语义保持)
     */
    function test_TransferAfterRebase() public {
        // 先给 Alice 一些代币
        token.transfer(alice, 100e18);

        // Rebase
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 bobBalanceBefore = token.balanceOf(bob);
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Alice 转给 Bob 10e18
        vm.prank(alice);
        token.transfer(bob, 10e18);

        assertEq(
            token.balanceOf(bob),
            bobBalanceBefore + 10e18,
            "Bob should receive 10e18"
        );
        assertEq(
            token.balanceOf(alice),
            aliceBalanceBefore - 10e18,
            "Alice should send 10e18"
        );
    }

    /**
     * @dev 测试: rebase 后转账的 gons 计算正确
     */
    function test_TransferAfterRebaseGonsCorrect() public {
        token.transfer(alice, 100e18);

        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 newGonsPerFragment = token.gonsPerFragment();
        uint256 transferAmount = 10e18;
        uint256 expectedGonValue = transferAmount * newGonsPerFragment;

        uint256 bobGonsBefore = token.gonBalanceOf(bob);

        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(
            token.gonBalanceOf(bob),
            bobGonsBefore + expectedGonValue,
            "Bob gons should increase correctly"
        );
    }

    // ============ 6. Allowance + transferFrom 测试 ============

    /**
     * @dev 测试: approve 和 allowance
     */
    function test_ApproveAndAllowance() public {
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.approve(spender, 50e18);

        assertEq(
            token.allowance(alice, spender),
            50e18,
            "Allowance should be 50e18"
        );
    }

    /**
     * @dev 测试: transferFrom 成功
     */
    function test_TransferFrom() public {
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.approve(spender, 50e18);

        vm.prank(spender);
        token.transferFrom(alice, bob, 20e18);

        assertEq(token.balanceOf(bob), 20e18, "Bob should receive 20e18");
        assertEq(
            token.allowance(alice, spender),
            30e18,
            "Allowance should be 30e18"
        );
    }

    /**
     * @dev 测试: allowance 不随 rebase 缩放
     *
     * 这是关键测试:
     * 1. Alice approve spender 50e18
     * 2. Rebase 发生
     * 3. 检查 allowance 仍然是 50e18 (没有自动缩放)
     * 4. 尝试 transferFrom 20e18 成功
     * 5. allowance 变为 30e18
     *
     * 为什么 allowance 不缩放:
     * - allowance 代表"用户允许消费的代币数量"
     * - 这是用户主动设置的值，不应该被 rebase 改变
     * - 如果自动缩放，用户可能会困惑于授权额度的变化
     */
    function test_AllowanceDoesNotScaleWithRebase() public {
        // 给 Alice 足够的代币
        token.transfer(alice, 100e18);

        // Alice 授权 spender 50e18
        vm.prank(alice);
        token.approve(spender, 50e18);

        uint256 allowanceBefore = token.allowance(alice, spender);
        assertEq(
            allowanceBefore,
            50e18,
            "Allowance before rebase should be 50e18"
        );

        // Rebase
        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        // 检查 allowance 没有缩放
        uint256 allowanceAfter = token.allowance(alice, spender);
        assertEq(
            allowanceAfter,
            50e18,
            "Allowance after rebase should still be 50e18 (not scaled)"
        );

        // 虽然 Alice 的余额减少了，但只要余额 >= 20e18，transferFrom 仍然可以成功
        // Alice 原来有 100e18，rebase 后约有 99e18，仍然可以转 20e18
        vm.prank(spender);
        token.transferFrom(alice, bob, 20e18);

        assertEq(token.balanceOf(bob), 20e18, "Bob should receive 20e18");
        assertEq(
            token.allowance(alice, spender),
            30e18,
            "Allowance should be 30e18 after transfer"
        );
    }

    /**
     * @dev 测试: transferFrom 超过 allowance 失败
     */
    function test_TransferFromExceedsAllowance() public {
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.approve(spender, 50e18);

        vm.prank(spender);
        vm.expectRevert();
        token.transferFrom(alice, bob, 60e18);
    }

    /**
     * @dev 测试: 无限授权不会减少
     */
    function test_InfiniteAllowance() public {
        token.transfer(alice, 100e18);

        vm.prank(alice);
        token.approve(spender, type(uint256).max);

        vm.prank(spender);
        token.transferFrom(alice, bob, 50e18);

        assertEq(
            token.allowance(alice, spender),
            type(uint256).max,
            "Infinite allowance should not decrease"
        );
    }

    // ============ 7. 边界条件测试 ============

    /**
     * @dev 测试: 多次 rebase 后供应量正确
     */
    function test_MultipleRebases() public {
        uint256 supply = token.totalSupply();

        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + ONE_YEAR);
            token.rebase();

            uint256 expectedSupply = (supply * 99) / 100;
            // 由于舍入，使用近似比较
            assertApproxEqRel(
                token.totalSupply(),
                expectedSupply,
                1e14,
                "Supply should decrease by ~1% each year"
            );

            supply = token.totalSupply();
        }

        // 10 年后，供应量约为初始的 0.99^10 ≈ 0.904
        // 由于每次 rebase 都有舍入误差累积，使用更宽松的容差
        uint256 expectedAfter10Years = (INITIAL_SUPPLY * 90427) / 100000;
        assertApproxEqRel(
            token.totalSupply(),
            expectedAfter10Years,
            1e15, // 放宽容差以适应累积舍入误差
            "Supply after 10 years should be ~90.4%"
        );
    }

    /**
     * @dev 测试: 转账金额为 0
     */
    function test_TransferZeroAmount() public {
        token.transfer(alice, 0);
        assertEq(token.balanceOf(alice), 0);
    }

    /**
     * @dev 测试: 初始时间戳设置正确
     */
    function test_InitialTimestamp() public view {
        assertEq(
            token.lastRebaseTimestamp(),
            block.timestamp,
            "Initial timestamp should be deployment time"
        );
    }

    /**
     * @dev 测试: nextRebaseTime 计算正确
     */
    function test_NextRebaseTime() public view {
        assertEq(
            token.nextRebaseTime(),
            block.timestamp + ONE_YEAR,
            "Next rebase time should be 1 year from now"
        );
    }

    // ============ 8. 数值验证测试 ============

    /**
     * @dev 测试: gonsPerFragment 在 rebase 后增加
     */
    function test_GonsPerFragmentIncreasesAfterRebase() public {
        uint256 gonsPerFragmentBefore = token.gonsPerFragment();

        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 gonsPerFragmentAfter = token.gonsPerFragment();

        // gonsPerFragment 应该增加约 1% (因为 totalSupply 减少了 1%)
        // gonsPerFragment = TOTAL_GONS / totalSupply
        // newGonsPerFragment ≈ oldGonsPerFragment * 100 / 99
        assertGt(
            gonsPerFragmentAfter,
            gonsPerFragmentBefore,
            "gonsPerFragment should increase after rebase"
        );
        assertApproxEqRel(
            gonsPerFragmentAfter,
            (gonsPerFragmentBefore * 100) / 99,
            1e14,
            "gonsPerFragment should increase by ~1.01%"
        );
    }

    /**
     * @dev 测试: sum(balanceOf) <= totalSupply
     * 由于舍入误差，sum 可能略小于 totalSupply
     */
    function test_SumOfBalancesLessOrEqualTotalSupply() public {
        token.transfer(alice, 33_333_333e18);
        token.transfer(bob, 33_333_333e18);
        // deployer 剩余约 33_333_334e18

        vm.warp(block.timestamp + ONE_YEAR);
        token.rebase();

        uint256 total = token.totalSupply();
        uint256 sumBalances = token.balanceOf(alice) +
            token.balanceOf(bob) +
            token.balanceOf(deployer);

        assertLe(
            sumBalances,
            total,
            "Sum of balances should be <= totalSupply"
        );
        // 差距应该很小
        assertApproxEqAbs(
            sumBalances,
            total,
            3,
            "Sum should be very close to totalSupply"
        );
    }

    // ============ 9. 事件测试 ============

    /**
     * @dev 测试: Transfer 事件
     */
    function test_TransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(deployer, alice, 100e18);

        token.transfer(alice, 100e18);
    }

    /**
     * @dev 测试: Approval 事件
     */
    function test_ApprovalEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(deployer, spender, 100e18);

        token.approve(spender, 100e18);
    }

    // 辅助事件接口 - 必须与 IERC20 定义的事件名称完全一致
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
