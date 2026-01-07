// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {UniswapV2Pair} from "../src/core/UniswapV2Pair.sol";

/**
 * @title GetInitCodeHash
 * @notice 获取UniswapV2Pair合约的init_code_hash
 */
contract GetInitCodeHash is Script {
    function run() public view {
        bytes32 initCodeHash = keccak256(type(UniswapV2Pair).creationCode);
        console.log("==========================================");
        console.log("UniswapV2Pair init_code_hash:");
        console.logBytes32(initCodeHash);
        console.log("==========================================");
        console.log("Copy this hash to:");
        console.log("src/periphery/UniswapV2Library.sol");
        console.log("Line ~76: INIT_CODE_PAIR_HASH variable");
    }
}
