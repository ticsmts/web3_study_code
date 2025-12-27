// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./ITokenReceiver.sol";

interface IERC20Minimal {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address owner,
        address to,
        uint256 amount
    ) external returns (bool);
}

// ---- 你的 TokenBank / TokenBankV2 保持不变 ----
contract TokenBank {
    IERC20Minimal public immutable token;

    mapping(address => uint256) internal _deposits;
    uint256 public totalDeposits;

    // 简单防重入锁
    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(address tokenAddress) {
        require(tokenAddress != address(0), "TokenBank: token is zero address");
        token = IERC20Minimal(tokenAddress);
    }

    // 查看某个地址在银行的存款记录
    function depositedOf(address user) external view returns (uint256) {
        return _deposits[user];
    }

    // 存入：把用户“已授权给银行的额度”一次性全部存入
    function deposit() external nonReentrant returns (bool) {
        uint256 amount = token.allowance(msg.sender, address(this));
        require(amount > 0, "TokenBank: allowance is zero");

        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "TokenBank: transferFrom failed");

        _deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
        return true;
    }

    // 取出：把用户之前存入的全部取出
    function withdraw() external nonReentrant returns (bool) {
        uint256 amount = _deposits[msg.sender];
        require(amount > 0, "TokenBank: no deposits");

        // 先清零再转账，避免重入风险
        _deposits[msg.sender] = 0;
        totalDeposits -= amount;

        bool ok = token.transfer(msg.sender, amount);
        require(ok, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, amount);
        return true;
    }
}

contract TokenBankV2 is TokenBank, ITokenReceiver {
    constructor(address tokenAddress) TokenBank(tokenAddress) {}

    /// @notice Callback from token.transferWithCallback()
    /// @param operator The address that initiated the transfer
    /// @param from The address tokens are transferred from
    /// @param value Amount of tokens transferred
    /// @param data Additional data (unused in this implementation)
    function tokensReceived(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external override nonReentrant returns (bool) {
        // 1) 只接受"本银行绑定的 token"回调，防止别人伪造调用
        require(
            msg.sender == address(token),
            "TokenBankV2: only token can callback"
        );
        require(value > 0, "TokenBankV2: amount is zero");

        // 2) 记账
        _deposits[from] += value;
        totalDeposits += value;

        emit Deposit(from, value);
        return true;
    }
}

// TokenBankV3：在 V2 基础上新增 permitDeposit
contract TokenBankV3 is TokenBankV2 {
    constructor(address tokenAddress) TokenBankV2(tokenAddress) {}

    /// @notice 通过 EIP-2612 permit 离线签名完成授权 + 存款（1 笔链上交易）
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant returns (bool) {
        require(amount > 0, "TokenBankV3: amount is zero");

        // 1) 用签名把 allowance 写到链上（owner = msg.sender）
        IERC20Permit(address(token)).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );

        // 2) 拉取 token
        bool ok = token.transferFrom(msg.sender, address(this), amount);
        require(ok, "TokenBankV3: transferFrom failed");

        // 3) 记账
        _deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
        return true;
    }
}
