// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/MyToken.sol";
import {MyTimelock} from "../src/MyTimelock.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Bank} from "../src/Bank.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {
    TimelockController
} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DAOTreasuryTest
 * @notice Comprehensive test suite for DAO Treasury governance system
 */
contract DAOTreasuryTest is Test {
    MyToken public token;
    MyTimelock public timelock;
    MyGovernor public governor;
    Bank public bank;

    address public deployer;
    address public voter1;
    address public voter2;
    address public recipient;

    uint256 public constant TIMELOCK_MIN_DELAY = 1 days;
    uint48 public constant VOTING_DELAY = 1;
    uint32 public constant VOTING_PERIOD = 50400;
    uint256 public constant PROPOSAL_THRESHOLD = 0;
    uint256 public constant QUORUM_PERCENTAGE = 4;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant BANK_INITIAL_BALANCE = 100 ether;

    event WithdrawETH(address indexed to, uint256 amount);
    event Received(address indexed sender, uint256 amount);

    function setUp() public {
        deployer = makeAddr("deployer");
        voter1 = makeAddr("voter1");
        voter2 = makeAddr("voter2");
        recipient = makeAddr("recipient");

        vm.startPrank(deployer);

        // Deploy Token
        token = new MyToken("GovernanceToken", "GOV", deployer);

        // Deploy Timelock with deployer as temporary admin
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // Anyone can execute

        timelock = new MyTimelock(
            TIMELOCK_MIN_DELAY,
            proposers,
            executors,
            deployer
        );

        // Deploy Governor
        governor = new MyGovernor(
            token,
            timelock,
            VOTING_DELAY,
            VOTING_PERIOD,
            PROPOSAL_THRESHOLD,
            QUORUM_PERCENTAGE
        );

        // Deploy Bank
        bank = new Bank(deployer);

        // Configure roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));

        // Transfer Bank ownership to Timelock
        bank.transferOwnership(address(timelock));

        // Renounce admin role
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopPrank();

        // Fund the bank
        vm.deal(address(bank), BANK_INITIAL_BALANCE);
    }

    // ============ Basic Tests ============

    /**
     * @notice Test that Bank can receive ETH
     */
    function test_BankCanReceiveETH() public {
        uint256 depositAmount = 1 ether;
        uint256 balanceBefore = address(bank).balance;

        vm.deal(voter1, depositAmount);
        vm.prank(voter1);
        (bool success, ) = address(bank).call{value: depositAmount}("");

        assertTrue(success, "ETH transfer should succeed");
        assertEq(
            address(bank).balance,
            balanceBefore + depositAmount,
            "Bank balance should increase"
        );
    }

    /**
     * @notice Test that Bank emits event when receiving ETH
     */
    function test_BankReceiveEmitsEvent() public {
        uint256 depositAmount = 1 ether;
        vm.deal(voter1, depositAmount);

        vm.expectEmit(true, false, false, true);
        emit Received(voter1, depositAmount);

        vm.prank(voter1);
        (bool success, ) = address(bank).call{value: depositAmount}("");
        assertTrue(success);
    }

    // ============ Permission Tests ============

    /**
     * @notice Test that EOA cannot call withdrawETH (onlyOwner)
     */
    function test_EOACannotWithdraw() public {
        vm.prank(voter1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                voter1
            )
        );
        bank.withdrawETH(voter1, 1 ether);
    }

    /**
     * @notice Test that deployer cannot withdraw after ownership transfer
     */
    function test_DeployerCannotWithdrawAfterTransfer() public {
        vm.prank(deployer);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                deployer
            )
        );
        bank.withdrawETH(deployer, 1 ether);
    }

    /**
     * @notice Test that Bank owner is Timelock
     */
    function test_BankOwnerIsTimelock() public view {
        assertEq(
            bank.owner(),
            address(timelock),
            "Bank owner should be Timelock"
        );
    }

    // ============ Governance Success Tests ============

    /**
     * @notice Test complete governance flow for successful withdrawal
     * This is the main test covering: delegate -> propose -> vote -> queue -> execute
     */
    function test_GovernanceSuccessfulWithdrawal() public {
        uint256 withdrawAmount = 10 ether;
        uint256 bankBalanceBefore = address(bank).balance;

        // 1. Mint tokens to voter1 and delegate
        vm.startPrank(deployer);
        token.mint(voter1, 100_000 ether); // 10% of supply (above 4% quorum)
        vm.stopPrank();

        // CRITICAL: Voter MUST delegate to self to activate voting power
        vm.prank(voter1);
        token.delegate(voter1);

        // Move forward 1 block for checkpoint to be recorded
        vm.roll(block.number + 1);

        // Verify voting power
        uint256 votingPower = token.getVotes(voter1);
        assertGt(
            votingPower,
            0,
            "Voter should have voting power after delegation"
        );

        // 2. Create proposal to withdraw ETH
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawETH(address,uint256)",
            recipient,
            withdrawAmount
        );

        string memory description = "Withdraw 10 ETH to recipient";

        vm.prank(voter1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // 3. Wait for voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // Verify proposal is active
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Active),
            "Proposal should be Active"
        );

        // 4. Cast vote (For = 1)
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        // 5. Wait for voting period to end
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Verify proposal succeeded
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Succeeded),
            "Proposal should have Succeeded"
        );

        // 6. Queue in timelock
        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        // Verify proposal is queued
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Queued),
            "Proposal should be Queued"
        );

        // 7. Wait for timelock delay
        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY + 1);

        // 8. Execute
        governor.execute(targets, values, calldatas, descriptionHash);

        // Verify proposal executed
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Executed),
            "Proposal should be Executed"
        );

        // 9. Verify balances
        assertEq(
            address(bank).balance,
            bankBalanceBefore - withdrawAmount,
            "Bank balance should decrease"
        );
        assertEq(
            recipient.balance,
            withdrawAmount,
            "Recipient should receive ETH"
        );
    }

    /**
     * @notice Test that voting without delegation results in 0 voting power
     */
    function test_VotingWithoutDelegationHasNoPower() public {
        // Mint tokens but DO NOT delegate
        vm.prank(deployer);
        token.mint(voter1, 100_000 ether);

        vm.roll(block.number + 1);

        // Check voting power is 0
        uint256 votingPower = token.getVotes(voter1);
        assertEq(votingPower, 0, "Voting power should be 0 without delegation");
    }

    // ============ Governance Failure Tests ============

    /**
     * @notice Test proposal fails when Against votes > For votes
     */
    function test_GovernanceFailedAgainstWins() public {
        // Setup voters with tokens
        vm.startPrank(deployer);
        token.mint(voter1, 50_000 ether);
        token.mint(voter2, 100_000 ether); // voter2 has more tokens
        vm.stopPrank();

        // Both delegate to themselves
        vm.prank(voter1);
        token.delegate(voter1);
        vm.prank(voter2);
        token.delegate(voter2);

        vm.roll(block.number + 1);

        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawETH(address,uint256)",
            recipient,
            1 ether
        );
        string memory description = "Withdraw 1 ETH - should fail";

        vm.prank(voter1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Wait for voting delay
        vm.roll(block.number + VOTING_DELAY + 1);

        // voter1 votes For, voter2 votes Against
        vm.prank(voter1);
        governor.castVote(proposalId, 1); // For

        vm.prank(voter2);
        governor.castVote(proposalId, 0); // Against

        // Wait for voting period to end
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Verify proposal is defeated
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be Defeated"
        );

        // Try to queue - should fail
        bytes32 descriptionHash = keccak256(bytes(description));
        vm.expectRevert();
        governor.queue(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Test proposal fails when quorum is not reached
     */
    function test_GovernanceFailedQuorumNotReached() public {
        // Mint very small amount (way below 4% quorum)
        vm.prank(deployer);
        token.mint(voter1, 1_000 ether); // Only 0.1% of supply

        // Also mint to deployer to establish total supply for quorum calculation
        vm.prank(deployer);
        token.mint(deployer, INITIAL_SUPPLY);

        vm.prank(voter1);
        token.delegate(voter1);

        vm.roll(block.number + 1);

        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawETH(address,uint256)",
            recipient,
            1 ether
        );
        string memory description = "Withdraw 1 ETH - quorum not met";

        vm.prank(voter1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + VOTING_DELAY + 1);

        // Only voter1 votes (not enough for quorum)
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        // Verify proposal is defeated due to quorum
        assertEq(
            uint256(governor.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Proposal should be Defeated due to quorum"
        );
    }

    // ============ Security Tests ============

    /**
     * @notice Test withdraw with zero address reverts
     */
    function test_WithdrawToZeroAddressReverts() public {
        // We need to test via governance, but for unit test, let's use a mock
        // Create a new bank with test address as owner
        Bank testBank = new Bank(address(this));
        vm.deal(address(testBank), 1 ether);

        vm.expectRevert(Bank.ZeroAddress.selector);
        testBank.withdrawETH(address(0), 1 ether);
    }

    /**
     * @notice Test withdraw with zero amount reverts
     */
    function test_WithdrawZeroAmountReverts() public {
        Bank testBank = new Bank(address(this));
        vm.deal(address(testBank), 1 ether);

        vm.expectRevert(Bank.ZeroAmount.selector);
        testBank.withdrawETH(recipient, 0);
    }

    /**
     * @notice Test withdraw more than balance reverts
     */
    function test_WithdrawInsufficientBalanceReverts() public {
        Bank testBank = new Bank(address(this));
        vm.deal(address(testBank), 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                Bank.InsufficientBalance.selector,
                2 ether,
                1 ether
            )
        );
        testBank.withdrawETH(recipient, 2 ether);
    }

    // ============ Reentrancy Tests ============

    /**
     * @notice Test reentrancy protection on withdrawETH
     */
    function test_ReentrancyProtection() public {
        // Deploy a malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker();

        // Create bank with attacker as owner (for testing purposes)
        Bank testBank = new Bank(address(attacker));
        vm.deal(address(testBank), 10 ether);

        // Setup attacker
        attacker.setBank(testBank);

        // Attempt attack - the first call will trigger receive() which tries to call withdrawETH again
        // Due to nonReentrant, this should fail
        vm.expectRevert();
        attacker.attack();
    }

    // ============ ERC20 Withdrawal Tests ============

    /**
     * @notice Test ERC20 withdrawal through governance
     */
    function test_WithdrawERC20ThroughGovernance() public {
        // Create a mock ERC20 and send to bank
        MockERC20 mockToken = new MockERC20("MockToken", "MTK");
        mockToken.mint(address(bank), 1000 ether);

        // Setup voter
        vm.prank(deployer);
        token.mint(voter1, 100_000 ether);

        vm.prank(voter1);
        token.delegate(voter1);
        vm.roll(block.number + 1);

        // Create proposal
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(bank);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "withdrawERC20(address,address,uint256)",
            address(mockToken),
            recipient,
            500 ether
        );
        string memory description = "Withdraw 500 MockTokens";

        vm.prank(voter1);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + TIMELOCK_MIN_DELAY + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        // Verify
        assertEq(
            mockToken.balanceOf(recipient),
            500 ether,
            "Recipient should receive tokens"
        );
        assertEq(
            mockToken.balanceOf(address(bank)),
            500 ether,
            "Bank should have remaining tokens"
        );
    }
}

// ============ Helper Contracts ============

/**
 * @notice Malicious contract that attempts reentrancy attack
 */
contract ReentrancyAttacker {
    Bank public bank;
    uint256 public attackCount;

    function setBank(Bank _bank) external {
        bank = _bank;
    }

    function attack() external {
        bank.withdrawETH(address(this), 1 ether);
    }

    receive() external payable {
        attackCount++;
        if (attackCount < 3 && address(bank).balance >= 1 ether) {
            // Try to reenter
            bank.withdrawETH(address(this), 1 ether);
        }
    }
}

/**
 * @notice Simple ERC20 for testing
 */
contract MockERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
