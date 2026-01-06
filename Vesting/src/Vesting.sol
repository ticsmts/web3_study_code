// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Vesting
 * @dev A token holder contract that can release its token balance gradually like a typical vesting scheme,
 * with a cliff and discrete monthly linear release.
 */
contract Vesting {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable start;

    uint256 public constant CLIFF_MONTHS = 12;
    uint256 public constant VESTING_MONTHS = 24;
    uint256 public constant MONTH_IN_SECONDS = 30 days;

    uint256 public released;

    event TokensReleased(address beneficiary, uint256 amount);

    constructor(IERC20 _token, address _beneficiary) {
        require(address(_token) != address(0), "Token address cannot be zero");
        require(
            _beneficiary != address(0),
            "Beneficiary address cannot be zero"
        );

        token = _token;
        beneficiary = _beneficiary;
        start = block.timestamp;
    }

    /**
     * @notice Releases the amount of tokens that have already vested.
     */
    function release() public {
        uint256 amount = vestedAmount(block.timestamp) - released;
        require(amount > 0, "No tokens are due for release");

        released += amount;
        token.safeTransfer(beneficiary, amount);

        emit TokensReleased(beneficiary, amount);
    }

    /**
     * @notice Calculates the amount of tokens that has already vested.
     */
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        uint256 totalAllocation = token.balanceOf(address(this)) + released;

        if (timestamp < start + CLIFF_MONTHS * MONTH_IN_SECONDS) {
            return 0;
        } else {
            uint256 monthsPassed = (timestamp - start) / MONTH_IN_SECONDS;
            // monthsPassed will be at least 12 here.
            // Month 12 (start of month 13) yields 1/24
            // Month 13 (start of month 14) yields 2/24
            // ...
            // Month 35 (start of month 36) yields 24/24

            uint256 monthsSinceCliffStarted = monthsPassed - CLIFF_MONTHS;
            uint256 vestedMonths = monthsSinceCliffStarted + 1;

            if (vestedMonths >= VESTING_MONTHS) {
                return totalAllocation;
            } else {
                return (totalAllocation * vestedMonths) / VESTING_MONTHS;
            }
        }
    }
}
