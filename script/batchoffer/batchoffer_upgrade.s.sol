pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../../src/batchoffer/BatchOffer.sol";

contract BatchOfferDeploy is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        // Get Market Config Values from .env
        address batchofferProxy = vm.envAddress("BATCHOFFER_PROXY");

        BatchOfferCreator offerCreator = new BatchOfferCreator();

        BatchOfferCreator batchOfferCreatorProxy = BatchOfferCreator(batchofferProxy);
        batchOfferCreatorProxy.upgradeTo(address(offerCreator));
    }
}