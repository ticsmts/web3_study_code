// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    event Submit(uint256 indexed txId, address indexed proposer, address indexed to, uint256 value, bytes data);
    event Confirm(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId, address indexed executor, bool success, bytes returnData);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public threshold;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 txId) {
        require(!isConfirmed[txId][msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "invalid threshold");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "zero owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    receive() external payable {}

    function submit(address to, uint256 value, bytes calldata data)
        external
        onlyOwner
        returns (uint256 txId)
    {
        require(to != address(0), "zero to");

        txId = transactions.length;
        transactions.push(
            Transaction({
                to: to,
                value: value,
                data: data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit Submit(txId, msg.sender, to, value, data);
    }

    function confirm(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
        notConfirmed(txId)
    {
        isConfirmed[txId][msg.sender] = true;
        transactions[txId].numConfirmations += 1;

        emit Confirm(msg.sender, txId);
    }

    function execute(uint256 txId)
        external
        txExists(txId)
        notExecuted(txId)
    {
        Transaction storage txn = transactions[txId];
        require(txn.numConfirmations >= threshold, "not enough confirmations");

        // CEI: effects first
        txn.executed = true;

        (bool ok, bytes memory ret) = txn.to.call{value: txn.value}(txn.data);
        require(ok, "tx failed");

        emit Execute(txId, msg.sender, ok, ret);
    }

    // 可选：辅助读取
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }
}
