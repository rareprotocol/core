// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../../../src/token/ERC721/sovereign/SovereignNFTContractFactory.sol";

contract SovereignNFTFactoryDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Logic Contracts
        new SovereignNFTContractFactory();

        vm.stopBroadcast();
    }
}
