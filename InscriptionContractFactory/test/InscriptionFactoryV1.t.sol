// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/InscriptionFactoryV1.sol";
import "../src/InscriptionToken.sol";

contract InscriptionFactoryV1Test is Test {
    InscriptionFactoryV1 public factory;
    InscriptionFactoryV1 public factoryImpl;

    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);

    event InscriptionDeployed(
        address indexed token,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint
    );

    event InscriptionMinted(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    function setUp() public {
        // 部署实现合约
        factoryImpl = new InscriptionFactoryV1();

        // 部署代理合约
        bytes memory initData = abi.encodeWithSelector(
            InscriptionFactoryV1.initialize.selector,
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);
        factory = InscriptionFactoryV1(address(proxy));
    }

    function test_Initialize() public view {
        assertEq(factory.owner(), owner);
        assertEq(factory.version(), "1.0.0");
    }

    function test_DeployInscription() public {
        vm.startPrank(user1);

        vm.expectEmit(false, true, false, true);
        emit InscriptionDeployed(
            address(0),
            user1,
            "TEST",
            1000 ether,
            10 ether
        );

        address tokenAddr = factory.deployInscription(
            "TEST",
            1000 ether,
            10 ether
        );

        vm.stopPrank();

        // 验证铭文信息
        (
            address creator,
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 totalMinted,
            uint256 remainingSupply
        ) = factory.getInscriptionInfo(tokenAddr);

        assertEq(creator, user1);
        assertEq(symbol, "TEST");
        assertEq(totalSupply, 1000 ether);
        assertEq(perMint, 10 ether);
        assertEq(totalMinted, 0);
        assertEq(remainingSupply, 1000 ether);

        // 验证代币合约
        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.name(), "TEST");
        assertEq(token.symbol(), "TEST");
        assertEq(token.maxSupply(), 1000 ether);
        assertEq(token.perMint(), 10 ether);
        assertEq(token.factory(), address(factory));
    }

    function test_MintInscription() public {
        // 部署铭文
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "MINT",
            100 ether,
            10 ether
        );

        // 铸造铭文
        vm.startPrank(user2);

        vm.expectEmit(true, true, false, true);
        emit InscriptionMinted(tokenAddr, user2, 10 ether);

        factory.mintInscription(tokenAddr);

        vm.stopPrank();

        // 验证余额
        InscriptionToken token = InscriptionToken(tokenAddr);
        assertEq(token.balanceOf(user2), 10 ether);
        assertEq(token.totalMinted(), 10 ether);
        assertEq(token.remainingSupply(), 90 ether);
    }

    function test_MultipleMints() public {
        // 部署铭文 (最多可铸造 5 次)
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "MULTI",
            50 ether,
            10 ether
        );

        InscriptionToken token = InscriptionToken(tokenAddr);

        // 铸造 5 次
        for (uint i = 0; i < 5; i++) {
            vm.prank(user2);
            factory.mintInscription(tokenAddr);
        }

        assertEq(token.balanceOf(user2), 50 ether);
        assertEq(token.totalMinted(), 50 ether);
        assertEq(token.remainingSupply(), 0);
    }

    function test_MintExceedsMaxSupply() public {
        // 部署铭文 (最多可铸造 2 次)
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "LIMIT",
            20 ether,
            10 ether
        );

        // 铸造 2 次成功
        vm.prank(user2);
        factory.mintInscription(tokenAddr);
        vm.prank(user2);
        factory.mintInscription(tokenAddr);

        // 第 3 次铸造应该失败
        vm.prank(user2);
        vm.expectRevert(InscriptionToken.ExceedsMaxSupply.selector);
        factory.mintInscription(tokenAddr);
    }

    function test_OnlyFactoryCanMint() public {
        vm.prank(user1);
        address tokenAddr = factory.deployInscription(
            "ONLY",
            100 ether,
            10 ether
        );

        InscriptionToken token = InscriptionToken(tokenAddr);

        // 直接调用 mint 应该失败
        vm.prank(user2);
        vm.expectRevert(InscriptionToken.OnlyFactory.selector);
        token.mint(user2);
    }

    function test_DeployInscription_InvalidParameters() public {
        vm.startPrank(user1);

        // 空 symbol
        vm.expectRevert(InscriptionFactoryV1.InvalidParameters.selector);
        factory.deployInscription("", 100 ether, 10 ether);

        // totalSupply 为 0
        vm.expectRevert(InscriptionFactoryV1.InvalidParameters.selector);
        factory.deployInscription("TEST", 0, 10 ether);

        // perMint 为 0
        vm.expectRevert(InscriptionFactoryV1.InvalidParameters.selector);
        factory.deployInscription("TEST", 100 ether, 0);

        // perMint > totalSupply
        vm.expectRevert(InscriptionFactoryV1.InvalidParameters.selector);
        factory.deployInscription("TEST", 10 ether, 100 ether);

        vm.stopPrank();
    }

    function test_MintInscription_NotFound() public {
        vm.prank(user1);
        vm.expectRevert(InscriptionFactoryV1.InscriptionNotFound.selector);
        factory.mintInscription(address(0x999));
    }

    function test_GetInscriptionsCount() public {
        assertEq(factory.getInscriptionsCount(), 0);

        vm.startPrank(user1);
        factory.deployInscription("A", 100 ether, 10 ether);
        assertEq(factory.getInscriptionsCount(), 1);

        factory.deployInscription("B", 200 ether, 20 ether);
        assertEq(factory.getInscriptionsCount(), 2);
        vm.stopPrank();
    }

    function test_AllInscriptions() public {
        vm.startPrank(user1);
        address token1 = factory.deployInscription("A", 100 ether, 10 ether);
        address token2 = factory.deployInscription("B", 200 ether, 20 ether);
        vm.stopPrank();

        assertEq(factory.allInscriptions(0), token1);
        assertEq(factory.allInscriptions(1), token2);
    }
}
