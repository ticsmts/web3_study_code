// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";
import {MyTimelock} from "../src/MyTimelock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Bank} from "../src/Bank.sol";
import {
    TimelockController
} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title Deploy
 * @notice Deployment script for the DAO Treasury system
 * @dev Deployment order: Token -> Timelock -> Governor -> Bank
 *
 * Post-deployment configuration:
 * 1. Grant PROPOSER_ROLE and CANCELLER_ROLE to Governor
 * 2. Transfer Bank ownership to Timelock
 * 3. Revoke DEFAULT_ADMIN_ROLE from deployer (minimum privilege)
 */
contract Deploy is Script {
    // Default configuration values
    uint256 public constant TIMELOCK_MIN_DELAY = 1 days;
    uint48 public constant VOTING_DELAY = 1; // 1 block
    uint32 public constant VOTING_PERIOD = 50400; // ~1 week (assuming 12s blocks)
    uint256 public constant PROPOSAL_THRESHOLD = 0; // Anyone can propose
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4% of total supply
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether; // 1M tokens

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying from:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Token
        MyToken token = new MyToken("GovernanceToken", "GOV", deployer);
        console.log("MyToken deployed at:", address(token));

        // Mint initial supply to deployer
        token.mint(deployer, INITIAL_SUPPLY);
        console.log("Minted", INITIAL_SUPPLY / 1 ether, "tokens to deployer");

        // 2. Deploy Timelock
        // EXECUTOR_ROLE = address(0) means anyone can execute passed proposals
        // This is more decentralized than restricting to Governor only
        address[] memory proposers = new address[](0); // Will add Governor later
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute

        MyTimelock timelock = new MyTimelock(
            TIMELOCK_MIN_DELAY,
            proposers,
            executors,
            deployer // Temporary admin, will renounce
        );
        console.log("MyTimelock deployed at:", address(timelock));

        // 3. Deploy Governor
        MyGovernor governor = new MyGovernor(
            token,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE
        );
        console.log("MyGovernor deployed at:", address(governor));

        // 4. Deploy Bank (owner = deployer initially)
        Bank bank = new Bank(deployer);
        console.log("Bank deployed at:", address(bank));

        // 5. Configure Timelock roles
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timelock.CANCELLER_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        // Grant PROPOSER and CANCELLER roles to Governor
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(cancellerRole, address(governor));
        console.log("Granted PROPOSER_ROLE and CANCELLER_ROLE to Governor");

        // 6. Transfer Bank ownership to Timelock
        bank.transferOwnership(address(timelock));
        console.log("Bank ownership transferred to Timelock");

        // 7. Revoke admin role from deployer (minimum privilege principle)
        // After this, only governance can change roles
        timelock.renounceRole(adminRole, deployer);
        console.log("Deployer renounced DEFAULT_ADMIN_ROLE");

        vm.stopBroadcast();

        console.log("\n=== Deployment Complete ===");
        console.log("Token:", address(token));
        console.log("Timelock:", address(timelock));
        console.log("Governor:", address(governor));
        console.log("Bank:", address(bank));
        console.log("\nIMPORTANT: Remember to delegate tokens before voting!");
    }
}
