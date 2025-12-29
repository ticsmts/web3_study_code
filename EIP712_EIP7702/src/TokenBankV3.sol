// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "./ITokenReceiver.sol";
import "./IPermit2.sol";

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

// TokenBankV4：在 V3 基础上新增 Permit2 存款
// Permit2 允许任何 ERC20 代币使用签名授权转账（无需 token 内置 permit 支持）
contract TokenBankV4 is TokenBankV3 {
    IPermit2 public permit2;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "TokenBankV4: not owner");
        _;
    }

    constructor(address tokenAddress) TokenBankV3(tokenAddress) {
        owner = msg.sender;
    }

    /// @notice 设置 Permit2 合约地址（仅 owner）
    function setPermit2(address permit2Address) external onlyOwner {
        require(
            permit2Address != address(0),
            "TokenBankV4: permit2 is zero address"
        );
        permit2 = IPermit2(permit2Address);
    }

    /// @notice 使用 Permit2 签名进行存款
    /// @dev 用户需要先 approve token 给 Permit2 合约
    /// @param amount 存款金额
    /// @param nonce Permit2 nonce（从 nonceBitmap 获取未使用的 nonce）
    /// @param deadline 签名过期时间
    /// @param signature 用户对 PermitTransferFrom 的签名
    function depositWithPermit2(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant returns (bool) {
        require(amount > 0, "TokenBankV4: amount is zero");
        require(block.timestamp <= deadline, "TokenBankV4: signature expired");

        // 1) 构造 Permit2 参数
        IPermit2.PermitTransferFrom memory permit = IPermit2
            .PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({
                    token: address(token),
                    amount: amount
                }),
                nonce: nonce,
                deadline: deadline
            });

        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2
            .SignatureTransferDetails({
                to: address(this),
                requestedAmount: amount
            });

        // 2) 通过 Permit2 执行签名转账
        // Permit2 会验证签名并调用 token.transferFrom(owner, to, amount)
        permit2.permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,
            signature
        );

        // 3) 记账
        _deposits[msg.sender] += amount;
        totalDeposits += amount;

        emit Deposit(msg.sender, amount);
        return true;
    }

    /// @notice 获取用户的 Permit2 nonce bitmap
    /// @dev 用于前端查找未使用的 nonce
    function getPermit2NonceBitmap(
        address owner,
        uint256 wordPos
    ) external view returns (uint256) {
        return permit2.nonceBitmap(owner, wordPos);
    }
}
