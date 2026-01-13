// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ========================
// OptionToken - 全抵押欧式看涨期权 Token (ERC20)
// 项目方存入 ETH 作为抵押，铸造等量的期权 Token (oETHC)
// 用户可在到期窗口内按行权价支付 USDT 行权，获得 ETH
// ========================

// ========================
// 自定义错误
// ========================
error NotIssuer();
error NotInExerciseWindow();
error NotExpired();
error InsufficientBalance();
error InsufficientAllowance();
error InsufficientETHCollateral();
error ETHTransferFailed();

// ========================
// IERC20 接口（只需 transferFrom）
// ========================
interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
}

/**
 * @title ReentrancyGuard
 * @dev 防重入保护，简化版实现
 */
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title OptionToken
 * @dev ERC20 期权 Token，代表对 ETH 的看涨期权
 */
contract OptionToken is ReentrancyGuard {
    // ========================
    // ERC20 状态变量
    // ========================
    string public constant name = "Option ETH Call";
    string public constant symbol = "oETHC";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ========================
    // 期权参数（部署时固定）
    // ========================
    address public immutable settlementToken; // USDT 合约地址
    uint256 public immutable strikePrice; // 行权价（USDT/ETH，以 USDT 最小单位计）
    uint256 public immutable expiry; // 到期时间戳
    uint256 public constant exerciseWindow = 1 days; // 行权窗口
    address public immutable issuer; // 项目方地址

    // ========================
    // 事件
    // ========================
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Issue(
        address indexed issuer,
        uint256 ethDeposited,
        uint256 optionsMinted
    );
    event Exercise(address indexed user, uint256 amountWei, uint256 usdtPaid);
    event Reclaim(address indexed issuer, uint256 ethReclaimed);

    // ========================
    // 修饰器
    // ========================
    modifier onlyIssuer() {
        if (msg.sender != issuer) revert NotIssuer();
        _;
    }

    /**
     * @dev 构造函数
     * @param _settlementToken USDT 合约地址
     * @param _strikePrice 行权价（例如：2000e6 表示 2000 USDT/ETH）
     * @param _expiry 到期时间戳
     * @param _issuer 项目方地址
     */
    constructor(
        address _settlementToken,
        uint256 _strikePrice,
        uint256 _expiry,
        address _issuer
    ) {
        require(_settlementToken != address(0), "Invalid settlement token");
        require(_strikePrice > 0, "Invalid strike price");
        require(_expiry > block.timestamp, "Expiry must be in future");
        require(_issuer != address(0), "Invalid issuer");

        settlementToken = _settlementToken;
        strikePrice = _strikePrice;
        expiry = _expiry;
        issuer = _issuer;
    }

    // ========================
    // 核心期权函数
    // ========================

    /**
     * @notice 项目方存入 ETH，铸造等量的期权 Token
     * @dev 只有 issuer 可以调用，1 wei ETH = 1 wei oETHC
     */
    function issue() external payable onlyIssuer {
        require(msg.value > 0, "Must deposit ETH");

        uint256 amount = msg.value;
        _mint(issuer, amount);

        emit Issue(issuer, amount, amount);
    }

    /**
     * @notice 行权：用户支付 USDT 获得 ETH
     * @param amountWei 要行权的期权数量（单位：wei，对应 18 decimals）
     * @dev 只能在 [expiry, expiry + exerciseWindow) 内调用
     *      usdtToPay = amountWei * strikePrice / 1e18
     */
    function exercise(uint256 amountWei) external nonReentrant {
        // 时间检查：只能在到期窗口内行权
        if (
            block.timestamp < expiry ||
            block.timestamp >= expiry + exerciseWindow
        ) {
            revert NotInExerciseWindow();
        }

        // 检查用户余额
        if (balanceOf[msg.sender] < amountWei) {
            revert InsufficientBalance();
        }

        // 检查合约 ETH 余额
        if (address(this).balance < amountWei) {
            revert InsufficientETHCollateral();
        }

        // 计算需要支付的 USDT 数量
        // amountWei(wei) / 1e18 = ETH 数量
        // ETH 数量 * strikePrice(USDT最小单位/ETH) = USDT 最小单位
        uint256 usdtToPay = (amountWei * strikePrice) / 1e18;

        // 检查 USDT 授权
        IERC20 usdt = IERC20(settlementToken);
        if (usdt.allowance(msg.sender, address(this)) < usdtToPay) {
            revert InsufficientAllowance();
        }

        // 1. 先销毁期权 Token（修改状态）
        _burn(msg.sender, amountWei);

        // 2. 从用户转入 USDT 给 issuer
        bool success = usdt.transferFrom(msg.sender, issuer, usdtToPay);
        require(success, "USDT transfer failed");

        // 3. 转出 ETH 给用户
        (bool ok, ) = msg.sender.call{value: amountWei}("");
        if (!ok) revert ETHTransferFailed();

        emit Exercise(msg.sender, amountWei, usdtToPay);
    }

    /**
     * @notice 到期后赎回：项目方取回未被行权的 ETH
     * @dev 只能在 expiry + exerciseWindow 之后调用
     */
    function reclaimExpired() external onlyIssuer {
        // 时间检查：只能在窗口结束后赎回
        if (block.timestamp < expiry + exerciseWindow) {
            revert NotExpired();
        }

        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to reclaim");

        (bool ok, ) = issuer.call{value: ethBalance}("");
        if (!ok) revert ETHTransferFailed();

        emit Reclaim(issuer, ethBalance);
    }

    // ========================
    // ERC20 标准函数
    // ========================

    function transfer(address to, uint256 amount) external returns (bool) {
        return _transfer(msg.sender, to, amount);
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
        uint256 currentAllowance = allowance[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            allowance[from][msg.sender] = currentAllowance - amount;
        }
        return _transfer(from, to, amount);
    }

    // ========================
    // 内部函数
    // ========================

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero address");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "Burn from zero address");
        require(balanceOf[from] >= amount, "Burn exceeds balance");

        balanceOf[from] -= amount;
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }

    // ========================
    // 视图函数（辅助）
    // ========================

    /**
     * @notice 检查当前是否在行权窗口内
     */
    function isInExerciseWindow() external view returns (bool) {
        return
            block.timestamp >= expiry &&
            block.timestamp < expiry + exerciseWindow;
    }

    /**
     * @notice 检查期权是否已过期（窗口结束）
     */
    function isExpired() external view returns (bool) {
        return block.timestamp >= expiry + exerciseWindow;
    }

    /**
     * @notice 计算行权需要支付的 USDT 数量
     * @param amountWei 期权数量（wei）
     * @return usdtAmount USDT 数量（最小单位）
     */
    function calculateUsdtPayment(
        uint256 amountWei
    ) external view returns (uint256 usdtAmount) {
        return (amountWei * strikePrice) / 1e18;
    }
}
