// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/ZZTokenV2.sol";
import "../src/TokenBankV3.sol";
import "../src/SimpleDelegator.sol";

// 简化的 Permit2 合约（核心 SignatureTransfer 功能）
contract SimplePermit2 {
    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    error InvalidNonce();
    error SignatureExpired();
    error InvalidSigner();

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
                ),
                keccak256("Permit2"),
                block.chainid,
                address(this)
            )
        );
    }

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        if (block.timestamp > permit.deadline) revert SignatureExpired();

        _useUnorderedNonce(owner, permit.nonce);

        bytes32 tokenPermissionsHash = keccak256(
            abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted)
        );

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_FROM_TYPEHASH,
                        tokenPermissionsHash,
                        msg.sender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        address signer = _recoverSigner(msgHash, signature);
        if (signer != owner) revert InvalidSigner();

        (bool success, ) = permit.permitted.token.call(
            abi.encodeWithSelector(
                bytes4(keccak256("transferFrom(address,address,uint256)")),
                owner,
                transferDetails.to,
                transferDetails.requestedAmount
            )
        );
        require(success, "Transfer failed");
    }

    function _useUnorderedNonce(address from, uint256 nonce) internal {
        uint256 wordPos = nonce >> 8;
        uint256 bitPos = nonce & 255;
        uint256 bit = 1 << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^= bit;
        if (flipped & bit == 0) revert InvalidNonce();
    }

    function _recoverSigner(
        bytes32 hash,
        bytes calldata signature
    ) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }

        if (v < 27) v += 27;

        return ecrecover(hash, v, r, s);
    }
}

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);

        // 保持原有部署顺序，只在最后添加 Permit2

        // 1. 部署 ZZTokenV2 (和之前一样)
        ZZTokenV2 token = new ZZTokenV2(
            "ZZ Token V2",
            "ZZ",
            deployer,
            deployer,
            21000000 * 10 ** 18
        );
        console.log("ZZTokenV2 deployed at:", address(token));

        // 2. 部署 TokenBankV4 (现在不需要 permit2 地址了)
        TokenBankV4 bank = new TokenBankV4(address(token));
        console.log("TokenBankV4 deployed at:", address(bank));

        // 3. 部署 SimpleDelegator
        SimpleDelegator delegator = new SimpleDelegator();
        console.log("SimpleDelegator deployed at:", address(delegator));

        // 4. 分配测试代币
        address testAccount = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        if (testAccount != deployer) {
            token.transfer(testAccount, 100000 * 10 ** 18);
            console.log("Transferred 100,000 ZZ to test account:", testAccount);
        }

        // 5. 最后部署 SimplePermit2 (只有这个地址会变)
        SimplePermit2 permit2 = new SimplePermit2();
        console.log("SimplePermit2 deployed at:", address(permit2));

        // 6. 设置 TokenBankV4 的 permit2 地址
        bank.setPermit2(address(permit2));
        console.log("TokenBankV4.permit2 set to:", address(permit2));

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Deployer:", deployer);
        console.log("ZZTokenV2:", address(token));
        console.log("TokenBankV4:", address(bank));
        console.log("SimpleDelegator:", address(delegator));
        console.log("SimplePermit2:", address(permit2));

        console.log("\n=== Update frontend/config/contracts.ts ===");
        console.log("TOKEN_ADDRESS:", address(token));
        console.log("BANK_ADDRESS:", address(bank));
        console.log("DELEGATOR_ADDRESS:", address(delegator));
        console.log("PERMIT2_ADDRESS:", address(permit2));
    }
}
