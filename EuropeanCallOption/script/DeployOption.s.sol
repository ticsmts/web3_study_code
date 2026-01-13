// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {OptionToken} from "../src/OptionToken.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

/**
 * @title DeployOption
 * @notice 部署期权合约到本地节点
 * 使用命令: forge script script/DeployOption.s.sol --rpc-url http://localhost:8545 --broadcast
 */
contract DeployOption is Script {
    function run() external {
        // Anvil 默认账户 (0): 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        // 私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        address issuer = vm.addr(deployerPrivateKey);

        console.log("Deployer/Issuer address:", issuer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 MockUSDT
        MockUSDT usdt = new MockUSDT();
        console.log("MockUSDT deployed at:", address(usdt));

        // 2. 设置期权参数
        uint256 strikePrice = 2000e6; // 2000 USDT/ETH
        uint256 expiry = block.timestamp + 1 hours; // 1小时后到期（方便测试）

        console.log("Strike Price: 2000 USDT/ETH");
        console.log("Expiry timestamp:", expiry);
        console.log("Current timestamp:", block.timestamp);

        // 3. 部署 OptionToken
        OptionToken option = new OptionToken(
            address(usdt),
            strikePrice,
            expiry,
            issuer
        );
        console.log("OptionToken deployed at:", address(option));

        // 4. Issuer 存入 10 ETH，铸造期权
        option.issue{value: 10 ether}();
        console.log("Issued 10 ETH worth of options");
        console.log(
            "oETHC balance of issuer:",
            option.balanceOf(issuer) / 1e18,
            "oETHC"
        );

        vm.stopBroadcast();

        console.log("");
        console.log("========== DEPLOYMENT COMPLETE ==========");
        console.log("MockUSDT:", address(usdt));
        console.log("OptionToken:", address(option));
        console.log("");
        console.log("Next steps:");
        console.log("1. Transfer oETHC to users for testing");
        console.log("2. Mint USDT to users");
        console.log("3. Wait for expiry or use vm.warp");
        console.log("4. Users can exercise their options");
    }
}
