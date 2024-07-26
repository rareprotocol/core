// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../../src/airdrop/TokenMerkleDrop.sol";

contract TokenMerkleDropDeploy is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        // Create contract
        new TokenMerkleDrop(vm.envAddress("RARE_ADDRESS"), vm.envBytes32("MERKLE_ROOT"));

        vm.stopBroadcast();
    }
}
