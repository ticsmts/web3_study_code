// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UniswapV2ERC20
 * @notice Uniswap V2 LP代币实现，包含EIP-2612 permit功能
 * @notice Uniswap V2 LP token implementation with EIP-2612 permit support
 *
 * 核心功能 Core Features:
 * 1. 标准ERC20代币功能 / Standard ERC20 token functionality
 * 2. EIP-2612: 通过签名进行授权，无需链上交易 / Authorization via signature without on-chain transaction
 * 3. 域分隔符(Domain Separator): 防止跨链重放攻击 / Prevents cross-chain replay attacks
 */
contract UniswapV2ERC20 {
    string public constant name = "Uniswap V2";
    string public constant symbol = "UNI-V2";
    uint8 public constant decimals = 18;

    // 总供应量 Total supply of LP tokens
    uint public totalSupply;

    // 账户余额映射 Mapping of account balances
    mapping(address => uint) public balanceOf;

    // 授权额度映射: owner => spender => amount
    // Allowance mapping: owner => spender => amount
    mapping(address => mapping(address => uint)) public allowance;

    // EIP-2612 相关 EIP-2612 related
    // DOMAIN_SEPARATOR: 用于防止签名在不同链或合约间重放
    // DOMAIN_SEPARATOR: Prevents signature replay across different chains or contracts
    bytes32 public DOMAIN_SEPARATOR;

    // PERMIT_TYPEHASH: permit函数的类型哈希
    // PERMIT_TYPEHASH: Type hash for permit function
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // nonces: 每个地址的nonce，防止签名重放
    // nonces: Nonce for each address to prevent signature replay
    mapping(address => uint) public nonces;

    // 事件 Events
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() {
        uint chainId;
        assembly {
            chainId := chainid()
        }

        // 构建域分隔符，包含链ID、合约地址等信息
        // Build domain separator with chain ID, contract address, etc.
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    /**
     * @notice 铸造LP代币 Mint LP tokens
     * @param to 接收地址 Recipient address
     * @param value 铸造数量 Amount to mint
     */
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply + value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(address(0), to, value);
    }

    /**
     * @notice 销毁LP代币 Burn LP tokens
     * @param from 销毁地址 Address to burn from
     * @param value 销毁数量 Amount to burn
     */
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from] - value;
        totalSupply = totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    /**
     * @notice 设置授权额度 Set allowance
     * @param owner 代币所有者 Token owner
     * @param spender 被授权者 Spender
     * @param value 授权额度 Allowance amount
     */
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice 转账函数 Transfer function
     * @param to 接收地址 Recipient
     * @param value 转账数量 Transfer amount
     */
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice 内部转账逻辑 Internal transfer logic
     */
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    /**
     * @notice 授权函数 Approve function
     * @param spender 被授权者 Spender
     * @param value 授权额度 Allowance amount
     */
    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice 授权转账 Transfer from allowance
     * @dev 从授权额度中扣除并转账 Deduct from allowance and transfer
     */
    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool) {
        if (allowance[from][msg.sender] != type(uint).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        }
        _transfer(from, to, value);
        return true;
    }

    /**
     * @notice EIP-2612 permit函数: 通过签名授权，无需链上approve交易
     * @notice EIP-2612 permit function: Authorization via signature, no on-chain approve transaction needed
     *
     * 工作原理 How it works:
     * 1. 用户在链下签署授权消息 / User signs authorization message off-chain
     * 2. 第三方可以提交签名来完成授权 / Third party can submit signature to complete authorization
     * 3. 节省用户的gas费用 / Saves user's gas fees
     *
     * @param owner 代币所有者 Token owner
     * @param spender 被授权者 Spender
     * @param value 授权额度 Allowance amount
     * @param deadline 截止时间 Deadline timestamp
     * @param v 签名参数v Signature parameter v
     * @param r 签名参数r Signature parameter r
     * @param s 签名参数s Signature parameter s
     */
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 检查截止时间 Check deadline
        require(deadline >= block.timestamp, "UniswapV2: EXPIRED");

        // 构造EIP-712结构化数据摘要
        // Construct EIP-712 structured data digest
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", // EIP-191前缀 EIP-191 prefix
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );

        // 从签名恢复签名者地址 Recover signer address from signature
        address recoveredAddress = ecrecover(digest, v, r, s);

        // 验证签名者是否为owner / Verify signer is owner
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "UniswapV2: INVALID_SIGNATURE"
        );

        // 设置授权 Set allowance
        _approve(owner, spender, value);
    }
}
