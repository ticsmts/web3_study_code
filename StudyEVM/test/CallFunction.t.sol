// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {Storage} from "../src/CallFunction.sol";
import "forge-std/console.sol";

contract StudyEVM_TEST is Test {
    Storage s;
    function setUp() public {
        s = new Storage();
    }

    function test_callFunction() public {
        bytes memory functionCalldata = abi.encodeWithSignature(
            "store(uint256)",
            10
        );
        (bool ok, ) = address(s).call(functionCalldata);

        console.logBytes(functionCalldata); //0x6057361d000000000000000000000000000000000000000000000000000000000000000a
        console.logBytes4(bytes4(functionCalldata)); // 0x6057361d
        console.logUint(functionCalldata.length); // 36

        bytes4 selector = bytes4(keccak256("store(uint256)"));
        console.logBytes4(selector); // 0x6057361d

        require(ok, "call failed");
    }
}
