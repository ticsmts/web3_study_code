// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ITokenReceiver.sol";

/**
 * ZZTokenV2
 * - ERC20
 * - EIP-2612 (permit)
 * - transferWithCallback
 */

contract ZZTokenV2 is ERC20, ERC20Permit, Ownable {
    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner_,
        address initialReceiver_,
        uint256 initialSupply_
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_) // EIP-712 domain 里的 name 必须和 token name 对齐
        Ownable(initialOwner_)
    {
        if (initialSupply_ > 0) {
            _mint(initialReceiver_, initialSupply_);
        }
    }

    /// @notice Mint new tokens (only owner)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Transfer with callback - allows single-transaction deposits
    /// @param to Recipient address (usually a contract like TokenBank)
    /// @param value Amount to transfer
    /// @param data Additional data to pass to callback
    function transferWithCallback(
        address to,
        uint256 value,
        bytes memory data
    ) public returns (bool) {
        bool ok = transfer(to, value);
        require(ok, "ZZTokenV2: transfer failed");

        if (_isContract(to)) {
            bool handled = ITokenReceiver(to).tokensReceived(
                msg.sender, // operator
                msg.sender, // from
                value,
                data
            );
            require(handled, "ZZTokenV2: tokensReceived failed");
        }
        return true;
    }

    /// @notice Check if address is a contract
    function _isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
