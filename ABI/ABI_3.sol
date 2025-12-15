// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DataStorage {
    string private data;

    function setData(string memory newData) public {
        data = newData;
    }

    function getData() public view returns (string memory) {
        return data;
    }
}

contract DataConsumer {
    address private dataStorageAddress;

    constructor(address _dataStorageAddress) {
        dataStorageAddress = _dataStorageAddress;
    }

    // 对 getData() 的函数签名和参数编码，调用成功后解码返回
    function getDataByABI() public view returns (string memory) {
        bytes memory payload = abi.encodeWithSignature("getData()");
        (bool success, bytes memory ret) = dataStorageAddress.staticcall(payload);
        require(success, "call function failed");

        return abi.decode(ret, (string));
    }

    // abi.encodeWithSignature() 调用 setData(string)
    function setDataByABI1(string calldata newData) public returns (bool) {
        bytes memory payload = abi.encodeWithSignature("setData(string)", newData);
        (bool success, ) = dataStorageAddress.call(payload);
        return success;
    }

    // abi.encodeWithSelector() 调用 setData(string)
    function setDataByABI2(string calldata newData) public returns (bool) {
        bytes4 selector = bytes4(keccak256("setData(string)"));
        bytes memory payload = abi.encodeWithSelector(selector, newData);

        (bool success, ) = dataStorageAddress.call(payload);
        return success;
    }

    // abi.encodeCall() 调用 setData(string)
    function setDataByABI3(string calldata newData) public returns (bool) {
        bytes memory payload = abi.encodeCall(DataStorage.setData, (newData));

        (bool success, ) = dataStorageAddress.call(payload);
        return success;
    }
}
