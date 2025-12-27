// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SimpleDelegator.sol";
import "../src/ZZTokenV2.sol";
import "../src/TokenBankV3.sol";

contract EIP7702Test is Test {
    SimpleDelegator public delegator;
    ZZTokenV2 public token;
    TokenBankV3 public bank;

    // Anvil account #0
    address constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 constant ALICE_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function setUp() public {
        // Deploy contracts with proper constructor params
        delegator = new SimpleDelegator();
        token = new ZZTokenV2(
            "ZZToken",
            "ZZ",
            address(this), // owner
            ALICE, // initial receiver
            10000 ether // initial supply
        );
        bank = new TokenBankV3(address(token));

        console.log("Delegator:", address(delegator));
        console.log("Token:", address(token));
        console.log("Bank:", address(bank));
        console.log("Alice token balance:", token.balanceOf(ALICE));
    }

    function testEIP7702Deposit() public {
        uint256 depositAmount = 100 ether;

        console.log("\n=== Before Deposit ===");
        console.log("Alice token balance:", token.balanceOf(ALICE));
        console.log("Alice bank deposit:", bank.depositedOf(ALICE));
        console.log("Alice code length:", ALICE.code.length);

        // Sign EIP-7702 delegation using Foundry cheatcode
        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(
            address(delegator),
            ALICE_PK
        );

        // Attach delegation - this sets ALICE's code to delegate to SimpleDelegator
        vm.attachDelegation(signedDelegation);

        console.log("\n=== After attachDelegation ===");
        console.log("Alice code length:", ALICE.code.length);

        // Create batch calls - approve + deposit
        // CRITICAL: When executed via delegation, msg.sender in the calls
        // will be ALICE (the EOA with delegated code)
        SimpleDelegator.Call[] memory calls = new SimpleDelegator.Call[](2);

        // Call 1: Approve bank to spend Alice's tokens
        calls[0] = SimpleDelegator.Call({
            target: address(token),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)",
                address(bank),
                depositAmount
            )
        });

        // Call 2: Call bank.deposit() - reads allowance and transfers
        calls[1] = SimpleDelegator.Call({
            target: address(bank),
            value: 0,
            data: abi.encodeWithSignature("deposit()")
        });

        // Call execute on Alice's address (now has delegator code)
        // The transaction originates from Alice
        vm.prank(ALICE);
        SimpleDelegator(payable(ALICE)).execute(calls);

        console.log("\n=== After Deposit ===");
        console.log("Alice token balance:", token.balanceOf(ALICE));
        console.log("Alice bank deposit:", bank.depositedOf(ALICE));

        // Verify deposit succeeded
        assertEq(
            bank.depositedOf(ALICE),
            depositAmount,
            "Deposit should succeed"
        );
    }

    // Test simpler case - just approve
    function testEIP7702Approve() public {
        uint256 approveAmount = 100 ether;

        console.log("\n=== Approve Test ===");
        console.log(
            "Alice allowance to bank before:",
            token.allowance(ALICE, address(bank))
        );

        Vm.SignedDelegation memory signedDelegation = vm.signDelegation(
            address(delegator),
            ALICE_PK
        );
        vm.attachDelegation(signedDelegation);

        SimpleDelegator.Call[] memory calls = new SimpleDelegator.Call[](1);
        calls[0] = SimpleDelegator.Call({
            target: address(token),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)",
                address(bank),
                approveAmount
            )
        });

        vm.prank(ALICE);
        SimpleDelegator(payable(ALICE)).execute(calls);

        console.log(
            "Alice allowance to bank after:",
            token.allowance(ALICE, address(bank))
        );

        assertEq(
            token.allowance(ALICE, address(bank)),
            approveAmount,
            "Approval should work"
        );
    }
}
