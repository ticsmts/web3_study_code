// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {ZZToken} from "../contracts/ZZToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";
import {MockAToken} from "../contracts/mocks/MockAToken.sol";
import {MockWETH} from "../contracts/mocks/MockWETH.sol";
import {MockLendingPool} from "../contracts/mocks/MockLendingPool.sol";

contract Deploy is Script {
    function run() external {
        bool deployMocks = vm.envOr("DEPLOY_MOCKS", false);

        vm.startBroadcast();

        address weth;
        address pool;

        if (deployMocks) {
            MockWETH mockWeth = new MockWETH();
            MockAToken mockAToken = new MockAToken();
            MockLendingPool mockPool = new MockLendingPool();
            mockPool.setAToken(address(mockWeth), address(mockAToken));
            mockAToken.setMinter(address(mockPool));
            weth = address(mockWeth);
            pool = address(mockPool);
        } else {
            weth = vm.envAddress("WETH_ADDRESS");
            pool = vm.envAddress("AAVE_POOL_ADDRESS");
        }

        ZZToken zz = new ZZToken();
        StakingPool staking = new StakingPool(address(zz), weth, pool);
        zz.setMinter(address(staking));

        vm.stopBroadcast();

        console2.log("ZZToken:", address(zz));
        console2.log("StakingPool:", address(staking));
        console2.log("WETH:", weth);
        console2.log("LendingPool:", pool);
        if (deployMocks) {
            console2.log("Mock aToken:", MockLendingPool(pool).aTokens(weth));
        }
    }
}
