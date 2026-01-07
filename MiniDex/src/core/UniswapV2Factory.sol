// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./UniswapV2Pair.sol";
import "../interfaces/IUniswapV2Factory.sol";

/**
 * @title UniswapV2Factory
 * @notice Uniswap V2 工厂合约 - 负责创建和管理交易对
 * @notice Uniswap V2 Factory Contract - Manages pair creation
 *
 * 核心功能 Core Functions:
 * 1. 使用CREATE2创建交易对，地址可预测 / Create pairs using CREATE2 for deterministic addresses
 * 2. 维护所有交易对的注册表 / Maintain registry of all pairs
 * 3. 管理协议手续费接收地址 / Manage protocol fee recipient
 */
contract UniswapV2Factory is IUniswapV2Factory {
    // 协议手续费接收地址 Protocol fee recipient address
    address public feeTo;

    // 有权设置feeTo地址的管理员 Admin with permission to set feeTo
    address public feeToSetter;

    // 交易对映射: token0 => token1 => pair地址
    // Pair mapping: token0 => token1 => pair address
    mapping(address => mapping(address => address)) public getPair;

    // 所有交易对数组 Array of all pairs
    address[] public allPairs;

    // 注意: PairCreated 事件继承自 IUniswapV2Factory 接口
    // Note: PairCreated event is inherited from IUniswapV2Factory interface

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    /**
     * @notice 获取交易对总数 Get total number of pairs
     */
    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    /**
     * @notice 创建交易对 Create trading pair
     * @dev 使用CREATE2确保地址确定性，便于链下计算
     * @dev Uses CREATE2 for deterministic addresses, enabling off-chain calculation
     *
     * CREATE2地址计算 CREATE2 Address Calculation:
     * address = keccak256(0xff + factory + salt + init_code_hash)[12:]
     * - salt = keccak256(abi.encodePacked(token0, token1))
     * - init_code_hash = keccak256(type(UniswapV2Pair).creationCode)
     *
     * 重要 IMPORTANT:
     * - init_code_hash在部署后不会改变 / init_code_hash doesn't change after deployment
     * - 必须在Router/Library中硬编码此值 / Must hardcode this value in Router/Library
     * - 可通过 keccak256(type(UniswapV2Pair).creationCode) 获取
     * - Can be obtained via keccak256(type(UniswapV2Pair).creationCode)
     *
     * @param tokenA 代币A地址 Token A address
     * @param tokenB 代币B地址 Token B address
     * @return pair 新创建的交易对地址 Newly created pair address
     */
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair) {
        require(tokenA != tokenB, "UniswapV2: IDENTICAL_ADDRESSES");

        // 按地址大小排序，确保token0 < token1
        // Sort by address to ensure token0 < token1
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "UniswapV2: ZERO_ADDRESS");
        require(
            getPair[token0][token1] == address(0),
            "UniswapV2: PAIR_EXISTS"
        );

        // 获取Pair合约创建字节码 Get Pair contract creation bytecode
        bytes memory bytecode = type(UniswapV2Pair).creationCode;

        // 计算salt: token0和token1的打包哈希
        // Calculate salt: packed hash of token0 and token1
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // 使用CREATE2创建合约，地址确定性
        // Create contract using CREATE2 for deterministic address
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // 初始化交易对 Initialize pair
        UniswapV2Pair(pair).initialize(token0, token1);

        // 双向记录映射 Record mapping bi-directionally
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @notice 设置协议手续费接收地址 Set protocol fee recipient
     * @dev 仅feeToSetter可调用 Only callable by feeToSetter
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    /**
     * @notice 设置feeToSetter管理员 Set feeToSetter admin
     * @dev 仅当前feeToSetter可调用 Only callable by current feeToSetter
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    /**
     * @notice 获取Pair合约的init code hash
     * @notice Get Pair contract init code hash
     * @dev 此哈希值需要硬编码到UniswapV2Library.pairFor()中
     * @dev This hash needs to be hardcoded in UniswapV2Library.pairFor()
     * @return hash Pair合约创建代码的keccak256哈希 keccak256 hash of Pair creation code
     */
    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(UniswapV2Pair).creationCode);
    }
}
