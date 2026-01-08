// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

import {ZZToken} from "../contracts/ZZToken.sol";
import {StakingPool} from "../contracts/StakingPool.sol";
import {MockAToken} from "../contracts/mocks/MockAToken.sol";
import {MockWETH} from "../contracts/mocks/MockWETH.sol";
import {MockLendingPool} from "../contracts/mocks/MockLendingPool.sol";

contract Flow is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        MockWETH weth = new MockWETH();
        MockAToken aToken = new MockAToken();
        MockLendingPool pool = new MockLendingPool();
        pool.setAToken(address(weth), address(aToken));
        aToken.setMinter(address(pool));
        ZZToken zz = new ZZToken();
        StakingPool staking = new StakingPool(address(zz), address(weth), address(pool));
        zz.setMinter(address(staking));

        staking.stake{value: 1 ether}();
        vm.roll(block.number + 10);
        staking.claim();
        vm.roll(block.number + 1);
        staking.unstake(1 ether);

        vm.stopBroadcast();

        console2.log("ZZToken:", address(zz));
        console2.log("StakingPool:", address(staking));
        console2.log("Mock aToken:", address(aToken));
        console2.log("Reward balance:", zz.balanceOf(vm.addr(pk)));
    }
}
