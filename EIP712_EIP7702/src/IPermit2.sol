// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IPermit2
/// @notice Interface for Uniswap's Permit2 SignatureTransfer functionality
/// @dev Minimal interface for signature-based token transfers
interface IPermit2 {
    /// @notice Token and amount for a permit
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    /// @notice The permit data for a single token signature-based transfer
    struct PermitTransferFrom {
        TokenPermissions permitted; // Token and max amount
        uint256 nonce; // Unique nonce per owner/token/spender
        uint256 deadline; // Signature expiration
    }

    /// @notice Details for the transfer recipient and amount
    struct SignatureTransferDetails {
        address to; // Recipient
        uint256 requestedAmount; // Actual amount to transfer (must be <= permitted.amount)
    }

    /// @notice Transfers a token using a signed permit message
    /// @param permit The permit data signed over by the owner
    /// @param transferDetails The spender's requested transfer details
    /// @param owner The owner of the tokens (signer)
    /// @param signature The signature over the permit data
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;

    /// @notice A mapping from owner to token to spender to a nonce value
    /// @dev Returns the index of the bitmap and the bit position within the bitmap
    function nonceBitmap(
        address owner,
        uint256 wordPos
    ) external view returns (uint256);
}
