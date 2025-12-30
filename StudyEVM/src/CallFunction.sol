// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

contract Storage {
    uint256 number;
    event Log(bytes data);
    function store(uint256 num) public {
        emit Log(msg.data); // 0x6057361d000000000000000000000000000000000000000000000000000000000000000a
        number = num;
    }

    function retrieve() public view returns (uint256) {
        return number;
    }

    // event FunctionCalldata(bytes);
    // function callFunction() public {
    //     bytes memory functionCalldata = abi.encodeWithSignature("store(uint256)", 10);
    //     emit FunctionCalldata(functionCalldata);
    //     (bool ok, ) = address(this).call(functionCalldata);
    //     require(ok, "call failed");
    // }
}
