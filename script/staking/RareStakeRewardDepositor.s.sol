// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {RarityPool} from "../../src/staking/token/RarityPool.sol";
import {RewardAccumulator} from "../../src/staking/reward/RewardAccumulator.sol";
import {RareStakingRegistry} from "../../src/staking/registry/RareStakingRegistry.sol";
import {RarityPoolFactory} from "../../src/staking/factory/RarityPoolFactory.sol";
import {RewardAccumulatorFactory} from "../../src/staking/factory/RewardAccumulatorFactory.sol";

contract RareStakeRewardDepositor is Script {
  function run() external {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    // Connect registry
    RareStakingRegistry registry = RareStakingRegistry(vm.envAddress("RARE_STAKING_REGISTRY"));

    // Connect RARE
    ERC20 rare = ERC20(vm.envAddress("RARE_ADDRESS"));

    // Increase Allowance if needed
    uint256 allowance = rare.allowance(vm.addr(vm.envUint("PRIVATE_KEY")), address(registry));
    if (allowance < 1_000_000 ether) {
      rare.increaseAllowance(address(registry), type(uint256).max);
    }

    // fetch all pools
    address[] memory allStakingContracts = registry.getAllStakingContracts();

    // send rewards
    for (uint256 i = 0; i < allStakingContracts.length; i++) {
      RarityPool(allStakingContracts[i]).addRewards(vm.addr(vm.envUint("PRIVATE_KEY")), genAmountToDistribute());
      RarityPool(allStakingContracts[i]).takeSnapshot();
    }
    vm.stopBroadcast();
  }

  function genAmountToDistribute() internal returns (uint256) {
    string[] memory cmds = new string[](1);
    cmds[0] = "script/staking/gennum.sh";
    bytes memory result = vm.ffi(cmds);
    uint256 randVal = uint256(bytes32(result));
    return (randVal % 10000) * 1 ether;
  }
}
