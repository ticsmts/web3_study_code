// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/MemeToken.sol";
import "../src/MemeFactory.sol";
import "../src/interfaces/IMiniDex.sol";

/**
 * @title Integration Test with Real MiniDex
 * @dev Test MemeFactory with actual UniswapV2 contracts
 */
contract IntegrationTest is Test {
    MemeToken public tokenImplementation;
    MemeFactory public factory;

    // Real MiniDex addresses on Anvil
    address public router = 0x0355B7B8cb128fA5692729Ab3AAa199C1753f726;
    address public weth = 0x8198f5d8F8CfFE8f9C413d98a0A55aEB8ab9FbB7;
    address public dexFactory = 0x36b58F5C1969B7b6591D752ea6F5486D069010AB;

    address public owner;
    address public creator;
    address public buyer;

    uint256 public constant TOTAL_SUPPLY = 1000000 * 1e18;
    uint256 public constant PER_MINT = 1000 * 1e18;
    uint256 public constant PRICE = 0.001 ether;

    function setUp() public {
        // Fork from local anvil
        owner = address(this);
        creator = makeAddr("creator");
        buyer = makeAddr("buyer");

        // Deploy MemeToken implementation
        tokenImplementation = new MemeToken();

        // Deploy MemeFactory with real MiniDex addresses
        factory = new MemeFactory(
            address(tokenImplementation),
            router,
            weth
        );

        // Give test accounts some ETH
        vm.deal(creator, 100 ether);
        vm.deal(buyer, 100 ether);
    }

    function test_MintWithRealDex() public {
        // Deploy Meme
        vm.prank(creator);
        address memeToken = factory.deployMeme(
            "PEPE",
            TOTAL_SUPPLY,
            PER_MINT,
            PRICE
        );

        console.log("MemeToken deployed at:", memeToken);
        console.log("Router:", router);
        console.log("WETH:", weth);
        console.log("DEX Factory:", dexFactory);

        uint256 mintCost = (PER_MINT * PRICE) / 1e18; // 1 ETH
        console.log("Mint cost:", mintCost);

        // Check pair before mint
        address pairBefore = IUniswapV2Factory(dexFactory).getPair(memeToken, weth);
        console.log("Pair before mint:", pairBefore);

        uint256 creatorBalanceBefore = creator.balance;

        // Buyer mints
        vm.prank(buyer);
        factory.mintMeme{value: mintCost}(memeToken);

        // Check results
        uint256 creatorReceived = creator.balance - creatorBalanceBefore;
        console.log("Creator received:", creatorReceived);

        uint256 projectFees = factory.projectFees();
        console.log("Project fees accumulated:", projectFees);

        // Check pair after mint
        address pairAfter = IUniswapV2Factory(dexFactory).getPair(memeToken, weth);
        console.log("Pair after mint:", pairAfter);

        // Check WETH balance of factory
        uint256 factoryWethBalance = IERC20(weth).balanceOf(address(factory));
        console.log("Factory WETH balance:", factoryWethBalance);

        // If pair exists, check reserves
        if (pairAfter != address(0)) {
            (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pairAfter).getReserves();
            console.log("Reserve0:", reserve0);
            console.log("Reserve1:", reserve1);
        }

        // Verify buyer got tokens
        assertEq(
            MemeToken(memeToken).balanceOf(buyer),
            PER_MINT,
            "Buyer should have tokens"
        );

        // Verify creator got 95%
        assertEq(
            creatorReceived,
            (mintCost * 95) / 100,
            "Creator should receive 95%"
        );
    }
}
