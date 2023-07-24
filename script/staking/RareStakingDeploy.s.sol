// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {IAccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {RarityPool} from "../../src/staking/token/RarityPool.sol";
import {RewardAccumulator} from "../../src/staking/reward/RewardAccumulator.sol";
import {RareStakingRegistry} from "../../src/staking/registry/RareStakingRegistry.sol";
import {RarityPoolFactory} from "../../src/staking/factory/RarityPoolFactory.sol";
import {RewardAccumulatorFactory} from "../../src/staking/factory/RewardAccumulatorFactory.sol";

contract RareStakingDeploy is Script {
  function run() external {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    // Deploy Logic Contracts
    RareStakingRegistry registry = new RareStakingRegistry();
    RarityPoolFactory factory = new RarityPoolFactory();
    RewardAccumulatorFactory rewardSwapFactoryLogic = new RewardAccumulatorFactory();
    RarityPool sRare = new RarityPool();
    RewardAccumulator rewardSwapTemp = new RewardAccumulator();

    // Deploy Proxies
    ERC1967Proxy registryProxy = new ERC1967Proxy(address(registry), "");
    ERC1967Proxy factoryProxy = new ERC1967Proxy(address(factory), "");
    ERC1967Proxy rewardSwapFactoryProxy = new ERC1967Proxy(address(rewardSwapFactoryLogic), "");

    // Initialize Proxies
    RareStakingRegistry(address(registryProxy)).initialize(
      vm.addr(vm.envUint("PRIVATE_KEY")),
      vm.envAddress("ENS_REVERSE_REGISTRAR"),
      vm.envAddress("ENS_RESOLVER"),
      10 minutes,
      1_00,
      10_00,
      vm.envAddress("RARE_ADDRESS"),
      vm.envAddress("WETH_ADDRESS"),
      vm.envAddress("DEFAULT_PAYEE")
    );
    RewardAccumulatorFactory(address(rewardSwapFactoryProxy)).initialize(
      address(rewardSwapTemp),
      vm.addr(vm.envUint("PRIVATE_KEY"))
    );
    RarityPoolFactory(address(factoryProxy)).initialize(
      address(registryProxy),
      address(sRare),
      address(rewardSwapFactoryProxy),
      vm.addr(vm.envUint("PRIVATE_KEY"))
    );

    // Grant Roles
    bytes32 stakingAddressSetterRole = RareStakingRegistry(address(registryProxy)).STAKING_INFO_SETTER_ROLE();
    bytes32 stakingStatAdminRole = RareStakingRegistry(address(registryProxy)).STAKING_STAT_SETTER_ADMIN_ROLE();

    IAccessControlUpgradeable(address(registryProxy)).grantRole(stakingAddressSetterRole, address(factoryProxy));
    IAccessControlUpgradeable(address(registryProxy)).grantRole(stakingStatAdminRole, address(factoryProxy));
    IAccessControlUpgradeable(address(registryProxy)).grantRole(
      RareStakingRegistry(address(registryProxy)).SWAP_POOL_SETTER_ROLE(),
      vm.addr(vm.envUint("PRIVATE_KEY"))
    );

    RareStakingRegistry(address(registryProxy)).setSwapPool(
      vm.envAddress("WETH_RARE_POOL_ADDRESS"),
      vm.envAddress("RARE_ADDRESS")
    );
    vm.stopBroadcast();
  }
}
