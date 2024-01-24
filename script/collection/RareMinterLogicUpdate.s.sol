// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/collection/RareMinter.sol";

contract RareMinterLogicUpdate is Script {
  function run() external {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
    address minterProxy = vm.envAddress("RARE_MINTER");
    RareMinter rareMinter = new RareMinter();
    RareMinter proxy = RareMinter(minterProxy);
    proxy.upgradeTo(address(rareMinter));
  }
}
