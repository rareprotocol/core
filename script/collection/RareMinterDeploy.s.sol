// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/collection/RareMinter.sol";

/////////////////////////////////////////////////////////////////////////
// Post Deployment Instructions
/////////////////////////////////////////////////////////////////////////
// Grant new marketplace settings the mark token role for old marketplace settings

contract RareMinterDeploy is Script {
  function run() external {
    uint256 privateKey = vm.envUint("PRIVATE_KEY");
    vm.startBroadcast(privateKey);
    address addr = vm.addr(privateKey);

    // Get Market Config Values from .env
    address networkBeneficiary = addr;
    address marketplaceSettings = vm.envAddress("SETTINGS_ADDRESS");
    address spaceOperatorRegistry = vm.envAddress("SPACE_OPERATOR_REGISTRY");
    address royaltyEngine = vm.envAddress("ROYALTY_ENGINE");
    address payments = vm.envAddress("PAYMENTS");
    address approvedTokenRegistry = vm.envAddress("TOKEN_REGISTRY");
    address stakingSettings = vm.envAddress("STAKING_SETTINGS");
    address stakingRegistry = vm.envAddress("STAKING_REGISTRY");

    RareMinter rareMinter = new RareMinter();

    ERC1967Proxy rareMinterProxy = new ERC1967Proxy(address(rareMinter), "");
    RareMinter(address(rareMinterProxy)).initialize(
      networkBeneficiary,
      marketplaceSettings,
      spaceOperatorRegistry,
      royaltyEngine,
      payments,
      approvedTokenRegistry,
      stakingSettings,
      stakingRegistry
    );

  }
}
