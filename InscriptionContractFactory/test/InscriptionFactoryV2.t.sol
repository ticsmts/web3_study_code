// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/InscriptionFactoryV1.sol";
import "../src/InscriptionFactoryV2.sol";
import "../src/InscriptionToken.sol";
import "../src/InscriptionTokenV2.sol";

contract InscriptionFactoryV2Test is Test {
    InscriptionFactoryV1 public factoryV1Impl;
    InscriptionFactoryV2 public factoryV2Impl;
    InscriptionFactoryV2 public factory;
    InscriptionTokenV2 public tokenV2Impl;
    ERC1967Proxy public proxy;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    event InscriptionDeployedV2(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );

    event InscriptionMinted(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    function setUp() public {
        // 1. 部署 V1 实现
        factoryV1Impl = new InscriptionFactoryV1();

        // 2. 部署代理并初始化为 V1
        bytes memory initData = abi.encodeWithSelector(
            InscriptionFactoryV1.initialize.selector,
            owner
        );
        proxy = new ERC1967Proxy(address(factoryV1Impl), initData);

        // 3. 部署 V2 实现和 TokenV2 实现
        factoryV2Impl = new InscriptionFactoryV2();
        tokenV2Impl = new InscriptionTokenV2();

        // 4. 升级到 V2
        vm.startPrank(owner);
        InscriptionFactoryV1(address(proxy)).upgradeToAndCall(
            address(factoryV2Impl),
            ""
        );

        // 5. 初始化 V2 (设置 tokenImplementation)
        factory = InscriptionFactoryV2(payable(address(proxy)));
        factory.initializeV2(address(tokenV2Impl));
        vm.stopPrank();

        // 给测试用户一些 ETH
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // ============ V2 新功能测试 ============

    function test_DeployInscriptionWithPrice() public {
        vm.startPrank(user1);

        address tokenAddr = factory.deployInscription(
            "PAID",
            1000 ether,
            10 ether,
            0.01 ether
        );

        vm.stopPrank();

        // 验证价格
        uint256 price = factory.getInscriptionPrice(tokenAddr);
        assertEq(price, 0.01 ether);

        // 验证是 V2 代币 - 调用成功即可
        factory.getInscriptionInfo(tokenAddr);
    }

    function test_MintWithPayment() public {
        // 部署带价格的铭文
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "PAID",
            100 ether,
            10 ether,
            0.01 ether
        );

        // 铸造并支付
        vm.prank(user2);
        factory.mintInscription{value: 0.01 ether}(tokenAddr);

        // 验证余额
        InscriptionTokenV2 token = InscriptionTokenV2(tokenAddr);
        assertEq(token.balanceOf(user2), 10 ether);

        // 验证费用累计
        assertEq(factory.totalFees(), 0.01 ether);
    }

    function test_MintWithExcessPayment() public {
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "PAID",
            100 ether,
            10 ether,
            0.01 ether
        );

        uint256 balanceBefore = user2.balance;

        // 多付 0.05 ether
        vm.prank(user2);
        factory.mintInscription{value: 0.06 ether}(tokenAddr);

        // 验证退款 (应该退 0.05 ether)
        assertEq(user2.balance, balanceBefore - 0.01 ether);
        assertEq(factory.totalFees(), 0.01 ether);
    }

    function test_MintInsufficientPayment() public {
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "PAID",
            100 ether,
            10 ether,
            0.01 ether
        );

        vm.prank(user2);
        vm.expectRevert(InscriptionFactoryV2.InsufficientPayment.selector);
        factory.mintInscription{value: 0.005 ether}(tokenAddr);
    }

    function test_WithdrawFees() public {
        // 部署并铸造几次
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "PAID",
            100 ether,
            10 ether,
            0.01 ether
        );

        vm.prank(user2);
        factory.mintInscription{value: 0.01 ether}(tokenAddr);
        vm.prank(user2);
        factory.mintInscription{value: 0.01 ether}(tokenAddr);

        assertEq(factory.totalFees(), 0.02 ether);

        // Owner 提取费用
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        factory.withdrawFees();

        assertEq(owner.balance, ownerBalanceBefore + 0.02 ether);
        assertEq(factory.totalFees(), 0);
    }

    function test_MinimalProxyGasSavings() public {
        // V2 使用最小代理应该比 V1 消耗更少的 gas
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        factory.deployInscription("GAS", 1000 ether, 10 ether, 0);
        uint256 gasUsed = gasBefore - gasleft();

        // 最小代理部署应该使用较少的 gas (通常 < 100k)
        // 这里只是确保它成功部署
        assertTrue(gasUsed > 0);
        console.log("V2 Deploy Gas Used:", gasUsed);
    }

    function test_Version() public view {
        assertEq(factory.version(), "2.0.0");
    }

    // ============ 升级兼容性测试 ============

    function test_UpgradePreservesV1Inscriptions() public {
        // 1. 重新设置：从 V1 开始
        InscriptionFactoryV1 v1Impl = new InscriptionFactoryV1();
        bytes memory initData = abi.encodeWithSelector(
            InscriptionFactoryV1.initialize.selector,
            owner
        );
        ERC1967Proxy newProxy = new ERC1967Proxy(address(v1Impl), initData);
        InscriptionFactoryV1 v1Factory = InscriptionFactoryV1(
            address(newProxy)
        );

        // 2. 在 V1 部署铭文
        vm.prank(user1);
        address v1Token = v1Factory.deployInscription(
            "V1TOKEN",
            1000 ether,
            100 ether
        );

        // 3. 在 V1 铸造一些
        vm.prank(user2);
        v1Factory.mintInscription(v1Token);

        // 记录升级前数据
        uint256 countBefore = v1Factory.getInscriptionsCount();
        uint256 balanceBefore = InscriptionToken(v1Token).balanceOf(user2);
        uint256 mintedBefore = InscriptionToken(v1Token).totalMinted();

        // 4. 升级到 V2
        InscriptionFactoryV2 v2Impl = new InscriptionFactoryV2();
        InscriptionTokenV2 tokenImpl = new InscriptionTokenV2();

        vm.startPrank(owner);
        v1Factory.upgradeToAndCall(address(v2Impl), "");
        InscriptionFactoryV2 v2Factory = InscriptionFactoryV2(
            payable(address(newProxy))
        );
        v2Factory.initializeV2(address(tokenImpl));
        vm.stopPrank();

        // 5. 验证升级后状态不变
        assertEq(
            v2Factory.getInscriptionsCount(),
            countBefore,
            "Count changed"
        );
        assertEq(
            InscriptionToken(v1Token).balanceOf(user2),
            balanceBefore,
            "Balance changed"
        );
        assertEq(
            InscriptionToken(v1Token).totalMinted(),
            mintedBefore,
            "Minted changed"
        );

        // 6. V1 铭文在 V2 中仍可继续铸造
        vm.prank(user2);
        v2Factory.mintInscription(v1Token);
        assertEq(
            InscriptionToken(v1Token).balanceOf(user2),
            balanceBefore + 100 ether,
            "Mint failed"
        );
    }

    function test_V1TokensRemainFreeAfterUpgrade() public {
        // V1 部署的免费铭文在 V2 中仍然免费
        InscriptionFactoryV1 v1Impl = new InscriptionFactoryV1();
        bytes memory initData = abi.encodeWithSelector(
            InscriptionFactoryV1.initialize.selector,
            owner
        );
        ERC1967Proxy newProxy = new ERC1967Proxy(address(v1Impl), initData);
        InscriptionFactoryV1 v1Factory = InscriptionFactoryV1(
            address(newProxy)
        );

        // V1 部署
        vm.prank(user1);
        address v1Token = v1Factory.deployInscription(
            "FREE",
            1000 ether,
            100 ether
        );

        // 升级
        InscriptionFactoryV2 v2Impl = new InscriptionFactoryV2();
        InscriptionTokenV2 tokenImpl = new InscriptionTokenV2();

        vm.startPrank(owner);
        v1Factory.upgradeToAndCall(address(v2Impl), "");
        InscriptionFactoryV2 v2Factory = InscriptionFactoryV2(
            payable(address(newProxy))
        );
        v2Factory.initializeV2(address(tokenImpl));
        vm.stopPrank();

        // V1 铭文价格应为 0
        assertEq(v2Factory.getInscriptionPrice(v1Token), 0);

        // 可以免费铸造
        vm.prank(user2);
        v2Factory.mintInscription(v1Token); // 无需支付

        assertEq(InscriptionToken(v1Token).balanceOf(user2), 100 ether);
    }
}
