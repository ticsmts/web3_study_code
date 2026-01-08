// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/**
 * @title ZZ Token
 */
interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title Staking Interface
 */
interface IStaking {
    /**
     * @dev ?? ETH ???
     */
    function stake() payable external;

    /**
     * @dev ????? ETH
     * @param amount ????
     */
    function unstake(uint256 amount) external;

    /**
     * @dev ?? ZZ Token ??
     */
    function claim() external;

    /**
     * @dev ????? ETH ??
     * @param account ????
     * @return ??? ETH ??
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev ?????? ZZ Token ??
     * @param account ????
     * @return ???? ZZ Token ??
     */
    function earned(address account) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

/**
 * @title StakingPool
 * @notice ETH ????: ??? 10 ZZ Token, ??????(accRewardPerShare)????
 */
contract StakingPool is IStaking {
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    uint256 public constant REWARD_PER_BLOCK = 10 ether;
    uint256 private constant ACC_PRECISION = 1e12;

    IToken public immutable zzToken;
    IWETH public immutable weth;
    IAavePool public immutable lendingPool;

    uint256 public lastRewardBlock;
    uint256 public accRewardPerShare;
    uint256 public totalStaked;

    mapping(address => UserInfo) public userInfo;

    bool private locked;

    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);

    modifier nonReentrant() {
        require(!locked, "StakingPool: reentrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address token, address wethAddress, address lendingPoolAddress) {
        require(token != address(0), "StakingPool: token zero");
        require(wethAddress != address(0), "StakingPool: weth zero");
        require(lendingPoolAddress != address(0), "StakingPool: pool zero");
        zzToken = IToken(token);
        weth = IWETH(wethAddress);
        lendingPool = IAavePool(lendingPoolAddress);
        lastRewardBlock = block.number;
    }

    receive() external payable {}

    function stake() external payable override nonReentrant {
        require(msg.value > 0, "StakingPool: zero amount");
        _updatePool();

        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = _pendingReward(user);
        if (pending > 0) {
            zzToken.mint(msg.sender, pending);
            emit Claim(msg.sender, pending);
        }

        weth.deposit{value: msg.value}();
        weth.approve(address(lendingPool), msg.value);
        lendingPool.supply(address(weth), msg.value, address(this), 0);

        user.amount += msg.value;
        totalStaked += msg.value;
        user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

        emit Stake(msg.sender, msg.value);
    }

    function unstake(uint256 amount) external override nonReentrant {
        require(amount > 0, "StakingPool: zero amount");
        _updatePool();

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "StakingPool: insufficient");

        uint256 pending = _pendingReward(user);
        if (pending > 0) {
            zzToken.mint(msg.sender, pending);
            emit Claim(msg.sender, pending);
        }

        user.amount -= amount;
        totalStaked -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;

        uint256 withdrawn = lendingPool.withdraw(address(weth), amount, address(this));
        weth.withdraw(withdrawn);
        (bool ok, ) = msg.sender.call{value: withdrawn}("");
        require(ok, "StakingPool: ETH transfer failed");

        emit Unstake(msg.sender, amount);
    }

    function claim() external override nonReentrant {
        _updatePool();

        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = _pendingReward(user);
        require(pending > 0, "StakingPool: no rewards");

        user.rewardDebt = (user.amount * accRewardPerShare) / ACC_PRECISION;
        zzToken.mint(msg.sender, pending);

        emit Claim(msg.sender, pending);
    }

    function balanceOf(address account) external view override returns (uint256) {
        return userInfo[account].amount;
    }

    function earned(address account) external view override returns (uint256) {
        UserInfo storage user = userInfo[account];
        uint256 currentAcc = accRewardPerShare;
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocks = block.number - lastRewardBlock;
            uint256 reward = blocks * REWARD_PER_BLOCK;
            currentAcc += (reward * ACC_PRECISION) / totalStaked;
        }
        return (user.amount * currentAcc) / ACC_PRECISION - user.rewardDebt;
    }

    function _updatePool() internal {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number - lastRewardBlock;
        uint256 reward = blocks * REWARD_PER_BLOCK;
        accRewardPerShare += (reward * ACC_PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }

    function _pendingReward(UserInfo storage user) internal view returns (uint256) {
        return (user.amount * accRewardPerShare) / ACC_PRECISION - user.rewardDebt;
    }
}