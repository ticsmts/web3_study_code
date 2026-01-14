// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Bank
 * @author DAO Treasury Project
 * @notice DAO Treasury contract that holds ETH and ERC20 tokens
 * @dev Designed to be owned by a Timelock, so withdrawals require governance approval
 *
 * Key features:
 * - Accepts ETH via receive() and explicit deposits
 * - ETH withdrawal via low-level call (not transfer) with reentrancy protection
 * - ERC20 withdrawal support with SafeERC20
 * - Owner-only withdrawals (owner should be set to Timelock)
 */
contract Bank is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Emitted when ETH is received
    /// @param sender Address that sent ETH
    /// @param amount Amount of ETH received
    event Received(address indexed sender, uint256 amount);

    /// @notice Emitted when ETH is withdrawn
    /// @param to Recipient address
    /// @param amount Amount of ETH withdrawn
    event WithdrawETH(address indexed to, uint256 amount);

    /// @notice Emitted when ERC20 tokens are withdrawn
    /// @param token Token contract address
    /// @param to Recipient address
    /// @param amount Amount of tokens withdrawn
    event WithdrawERC20(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /// @notice Custom errors for gas efficiency
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed();
    error ZeroAddress();
    error ZeroAmount();

    /**
     * @notice Initialize the Bank with an owner
     * @param initialOwner Address that will own the contract (should be Timelock)
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @notice Accept ETH transfers
     * @dev Emits Received event for tracking deposits
     */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @notice Explicitly deposit ETH with event
     */
    function deposit() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ETH from the treasury
     * @dev Only callable by owner (should be Timelock). Uses call for transfer.
     * @param to Recipient address
     * @param amount Amount of ETH to withdraw
     */
    function withdrawETH(
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > address(this).balance) {
            revert InsufficientBalance(amount, address(this).balance);
        }

        // Use call instead of transfer for better gas forwarding
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit WithdrawETH(to, amount);
    }

    /**
     * @notice Withdraw ERC20 tokens from the treasury
     * @dev Only callable by owner (should be Timelock). Uses SafeERC20.
     * @param token ERC20 token contract address
     * @param to Recipient address
     * @param amount Amount of tokens to withdraw
     */
    function withdrawERC20(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        token.safeTransfer(to, amount);

        emit WithdrawERC20(address(token), to, amount);
    }

    /**
     * @notice Get the ETH balance of the treasury
     * @return The current ETH balance
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
