// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MyToken
 * @author DAO Treasury Project
 * @notice ERC20 governance token with voting and permit capabilities
 * @dev Combines ERC20, ERC20Permit (EIP-2612), and ERC20Votes for governance
 * 
 * Key features:
 * - ERC20Votes: Enables vote delegation and historical voting power checkpoints
 * - ERC20Permit: Gasless approvals via EIP-2612 signatures
 * - Ownable: Only owner can mint new tokens
 * 
 * IMPORTANT: Token holders MUST delegate to themselves (or another address) 
 * before their tokens count as voting power. Without delegation, voting power = 0.
 */
contract MyToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    
    /// @notice Emitted when new tokens are minted
    /// @param to Recipient address
    /// @param amount Amount of tokens minted
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @notice Initialize the governance token
     * @param name Token name
     * @param symbol Token symbol
     * @param initialOwner Address that will own the contract and can mint tokens
     */
    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) ERC20Permit(name) Ownable(initialOwner) {}

    /**
     * @notice Mint new tokens to an address
     * @dev Only callable by owner. Recipient should delegate after receiving.
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    // ============ Required Overrides ============

    /**
     * @dev Override required by Solidity for ERC20Votes
     * Updates vote checkpoints on every transfer
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /**
     * @dev Override required by Solidity for ERC20Permit/ERC20Votes nonce handling
     */
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
