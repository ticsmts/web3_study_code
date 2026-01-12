// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RebaseDeflationaryToken
 * @author Study Implementation
 * @notice 采用 AMPL/Gons 模型的通缩型 Rebase ERC20 代币
 *
 * @dev 核心设计原理：
 *
 * 1. AMPL/Gons 模型
 *    - 内部使用 "gons"(份额) 作为存储单位
 *    - 对外显示 "fragments"(碎片) 作为用户看到的余额
 *    - gons 总量恒定不变，但 fragments 会随 rebase 缩放
 *
 * 2. 换算关系
 *    - gonsPerFragment = TOTAL_GONS / totalSupply
 *    - balanceOf(account) = _gonBalances[account] / gonsPerFragment
 *    - 当 totalSupply 减少时，gonsPerFragment 增大
 *    - 因此 balanceOf 返回值自动变小，无需遍历修改任何余额
 *
 * 3. 通缩机制
 *    - 每年通过 rebase() 减少 1% 的总供应量
 *    - S_{n+1} = S_n * 99 / 100
 *    - 所有账户的 fragments 余额同比例缩小，持仓占比不变
 *
 * 4. TOTAL_GONS 的构造
 *    - TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_SUPPLY)
 *    - 确保 TOTAL_GONS % INITIAL_SUPPLY == 0
 *    - 这样初始时 gonsPerFragment 是整数，减少舍入误差
 */

/**
 * @dev IERC20 接口
 */
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract RebaseDeflationaryToken is IERC20 {
    // ============ 常量 ============

    string private constant _name = "Rebase Deflationary Token";
    string private constant _symbol = "RDFT";
    uint8 private constant _decimals = 18;

    /**
     * @dev 初始供应量: 1亿个代币
     */
    uint256 public constant INITIAL_FRAGMENTS_SUPPLY = 100_000_000 * 1e18;

    /**
     * @dev 最小供应量: 1个代币
     * 当 totalSupply 低于此值时，rebase 会 clamp 到此值
     * 防止 supply 因整数除法变为 0
     */
    uint256 public constant MIN_SUPPLY = 1e18;

    /**
     * @dev Rebase 间隔: 365 天
     */
    uint256 public constant REBASE_INTERVAL = 365 days;

    /**
     * @dev TOTAL_GONS: 全系统总份额，恒定不变
     *
     * 构造方式: MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY)
     *
     * 为什么这样做:
     * 1. MAX_UINT256 是 uint256 能表示的最大值
     * 2. 减去余数后，TOTAL_GONS 可以被 INITIAL_FRAGMENTS_SUPPLY 整除
     * 3. 初始 gonsPerFragment = TOTAL_GONS / INITIAL_SUPPLY 是整数
     * 4. 这减少了后续计算的舍入误差
     *
     * 具体数值:
     * MAX_UINT256 ≈ 1.157 × 10^77
     * INITIAL_SUPPLY = 10^26 (100M * 1e18)
     * TOTAL_GONS ≈ 1.157 × 10^77 - (小余数)
     */
    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 public constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    // ============ 状态变量 ============

    /**
     * @dev 当前总供应量 (以 fragments 计)
     * 初始值 = INITIAL_FRAGMENTS_SUPPLY
     * 每次 rebase 后减少约 1%
     */
    uint256 private _totalSupply;

    /**
     * @dev gons 与 fragments 的换算比例
     * gonsPerFragment = TOTAL_GONS / _totalSupply
     *
     * 当 _totalSupply 减少时，gonsPerFragment 增大
     * 因此 balanceOf = gonBalance / gonsPerFragment 自动变小
     */
    uint256 private _gonsPerFragment;

    /**
     * @dev 内部余额存储 (以 gons 计)
     * 用户实际持有的 gons 份额，不会因 rebase 改变
     * 只有转账时才会改变
     */
    mapping(address => uint256) private _gonBalances;

    /**
     * @dev 授权额度 (以 fragments 计)
     *
     * 设计决策: allowance 不随 rebase 缩放
     * 原因:
     * 1. 这是 AMPL 的标准行为
     * 2. 授权额度是用户主动设置的，代表"允许花费的 fragments 数量"
     * 3. 如果 rebase 后自动缩放，会违反用户的预期
     * 4. 例如: 用户授权 100 个代币，rebase 后仍可以花费 100 个代币
     *    （即使这 100 个代币现在占总供应量的更大比例）
     */
    mapping(address => mapping(address => uint256)) private _allowances;

    /**
     * @dev 上次 rebase 的时间戳
     */
    uint256 public lastRebaseTimestamp;

    /**
     * @dev rebase 纪元计数器
     */
    uint256 public epoch;

    // ============ 事件 ============

    /**
     * @dev Rebase 事件
     * @param epoch 第几次 rebase
     * @param oldSupply 旧的总供应量
     * @param newSupply 新的总供应量
     * @param timestamp rebase 发生时间
     */
    event Rebase(
        uint256 indexed epoch,
        uint256 oldSupply,
        uint256 newSupply,
        uint256 timestamp
    );

    // ============ 错误 ============

    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSender(address sender);
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidSpender(address spender);
    error RebaseTooSoon(uint256 nextRebaseAt, uint256 currentTime);

    // ============ 构造函数 ============

    /**
     * @dev 构造函数
     * 将全部初始供应量 mint 给部署者
     */
    constructor() {
        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;

        // 计算初始 gonsPerFragment
        // gonsPerFragment = TOTAL_GONS / INITIAL_SUPPLY
        // 由于 TOTAL_GONS 的构造方式，这是一个整数
        _gonsPerFragment = TOTAL_GONS / _totalSupply;

        // 将全部 gons 分配给部署者
        // deployer 的 gonBalance = TOTAL_GONS (全部份额)
        // deployer 的 fragments = TOTAL_GONS / gonsPerFragment = INITIAL_SUPPLY
        _gonBalances[msg.sender] = TOTAL_GONS;

        // 记录初始时间
        lastRebaseTimestamp = block.timestamp;

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    // ============ ERC20 基础视图函数 ============

    function name() external pure override returns (string memory) {
        return _name;
    }

    function symbol() external pure override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev 返回总供应量 (以 fragments 计)
     */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev 返回账户余额 (以 fragments 计)
     *
     * 计算方式: fragments = gons / gonsPerFragment
     *
     * 示例:
     * - 初始状态: gonsPerFragment = TOTAL_GONS / 1e26 = X
     * - 用户 A 持有 1% 的 gons = TOTAL_GONS * 0.01
     * - 用户 A 的 fragments = (TOTAL_GONS * 0.01) / X = 1e24 (1M tokens)
     *
     * - Rebase 后: totalSupply = 0.99e26
     * - 新 gonsPerFragment = TOTAL_GONS / 0.99e26 = X / 0.99 ≈ 1.0101 * X
     * - 用户 A 的 gons 不变 = TOTAL_GONS * 0.01
     * - 用户 A 的 fragments = (TOTAL_GONS * 0.01) / (1.0101 * X) ≈ 0.99e24 (990K tokens)
     *
     * 用户的 fragments 余额自动减少了 1%，但持仓占比仍是 1%
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _gonBalances[account] / _gonsPerFragment;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    // ============ ERC20 写入函数 ============

    /**
     * @dev 转账函数
     * @param to 接收者地址
     * @param amount 转账金额 (以 fragments 计)
     *
     * 内部使用 gons 进行转账:
     * 1. 计算 gonValue = amount * gonsPerFragment
     * 2. 从发送者扣除 gonValue
     * 3. 给接收者增加 gonValue
     * 4. 事件中的 value 是 fragments (用户看到的数量)
     */
    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // ============ Rebase 函数 ============

    /**
     * @dev 执行 rebase，将总供应量减少 1%
     *
     * 任何人都可以调用 (permissionless)
     *
     * 设计原因:
     * 1. 去中心化: 不依赖 owner 来触发
     * 2. 激励兼容: 任何人都有动机在时机成熟时调用
     * 3. 可预测性: 规则透明，按时间自动生效
     *
     * 限制:
     * - 距离上次 rebase 至少 365 天
     * - 如果 newSupply < MIN_SUPPLY，clamp 到 MIN_SUPPLY
     */
    function rebase() external returns (uint256) {
        uint256 nextRebaseAt = lastRebaseTimestamp + REBASE_INTERVAL;
        if (block.timestamp < nextRebaseAt) {
            revert RebaseTooSoon(nextRebaseAt, block.timestamp);
        }

        uint256 oldSupply = _totalSupply;

        // 计算新供应量: S_{n+1} = S_n * 99 / 100
        // 注意: 整数除法可能导致精度损失
        uint256 newSupply = (oldSupply * 99) / 100;

        // 边界保护: 确保 newSupply >= MIN_SUPPLY
        // 当 oldSupply 很小时，newSupply 可能等于 oldSupply（因为整数除法）
        // 或者 newSupply 可能小于 MIN_SUPPLY
        // 我们选择 clamp 到 MIN_SUPPLY
        if (newSupply < MIN_SUPPLY) {
            newSupply = MIN_SUPPLY;
        }

        // 如果 newSupply 没有变化（可能因为已经到达 MIN_SUPPLY）
        // 仍然继续执行，更新时间戳，但供应量不变
        // 这样不会阻塞调用，但也不会改变任何实际状态

        // 更新 gonsPerFragment
        // 新的 gonsPerFragment = TOTAL_GONS / newSupply
        // 由于 newSupply 变小，gonsPerFragment 变大
        _gonsPerFragment = TOTAL_GONS / newSupply;

        // 重新计算 totalSupply 以保持一致性
        // totalSupply = TOTAL_GONS / gonsPerFragment
        //
        // 这里有两次除法的舍入问题:
        // 1. gonsPerFragment = TOTAL_GONS / newSupply (向下取整)
        // 2. totalSupply = TOTAL_GONS / gonsPerFragment (向下取整)
        //
        // 由于两次向下取整，最终 totalSupply 可能略大于 newSupply
        // 但这保证了 sum(balanceOf) <= totalSupply
        // 避免出现 sum(balanceOf) > totalSupply 的不一致情况
        _totalSupply = TOTAL_GONS / _gonsPerFragment;

        // 更新时间戳和纪元
        lastRebaseTimestamp = block.timestamp;
        epoch++;

        emit Rebase(epoch, oldSupply, _totalSupply, block.timestamp);

        return _totalSupply;
    }

    // ============ 视图辅助函数 ============

    /**
     * @dev 返回当前 gonsPerFragment
     */
    function gonsPerFragment() external view returns (uint256) {
        return _gonsPerFragment;
    }

    /**
     * @dev 返回账户的 gons 余额辅助函数 (用于测试)
     */
    function gonBalanceOf(address account) external view returns (uint256) {
        return _gonBalances[account];
    }

    /**
     * @dev 返回下次可以 rebase 的时间
     */
    function nextRebaseTime() external view returns (uint256) {
        return lastRebaseTimestamp + REBASE_INTERVAL;
    }

    // ============ 内部函数 ============

    /**
     * @dev 内部转账函数
     *
     * 转账逻辑:
     * 1. 将 fragments 金额转换为 gons: gonValue = amount * gonsPerFragment
     * 2. 检查发送者有足够的 gons
     * 3. 从发送者扣除 gonValue
     * 4. 给接收者增加 gonValue
     * 5. 发出 Transfer 事件 (value 是 fragments)
     *
     * 为什么用 gons 转账:
     * - gons 不受 rebase 影响
     * - 这确保了转账的原子性和一致性
     * - 例如: 用户 A 转给 B 100 fragments
     *   - gonValue = 100 * gonsPerFragment
     *   - 这个 gonValue 在转账前后代表相同的"份额比例"
     */
    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        // 将 fragments 转换为 gons
        uint256 gonValue = amount * _gonsPerFragment;

        uint256 fromGonBalance = _gonBalances[from];
        if (fromGonBalance < gonValue) {
            revert ERC20InsufficientBalance(
                from,
                fromGonBalance / _gonsPerFragment,
                amount
            );
        }

        unchecked {
            _gonBalances[from] = fromGonBalance - gonValue;
            // 由于总 gons 恒定，不会溢出
            _gonBalances[to] += gonValue;
        }

        emit Transfer(from, to, amount);
    }

    /**
     * @dev 内部授权函数
     * allowance 以 fragments 为单位存储
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev 消费授权额度
     *
     * 注意: allowance 不随 rebase 缩放
     * 这意味着:
     * - 用户授权 100 个代币
     * - rebase 后，这 100 个代币的购买力相对增加了
     *   （因为总供应量减少，但授权额度不变）
     * - 这是符合直觉的行为：授权是"允许花费的代币数量"
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = _allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    amount
                );
            }
            unchecked {
                _allowances[owner][spender] = currentAllowance - amount;
            }
        }
    }
}
