// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../lib/aux/src/marketplace/MarketplaceSettingsV1.sol";
import "../lib/aux/src/marketplace/MarketplaceSettingsV2.sol";
import "../lib/aux/src/marketplace/MarketplaceSettingsV3.sol";
import "../lib/aux/src/registry/SpaceOperatorRegistry.sol";
import "../lib/aux/src/registry/ApprovedTokenRegistry.sol";
import "../lib/aux/src/payments/Payments.sol";
import "../src/token/ERC721/superrare/SuperRareV2.sol";
import "../src/token/ERC20/SuperRareGovToken.sol";
import "../src/token/ERC721/sovereign/lazy/LazySovereignNFTFactory.sol";

contract NetworkDeploy is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address addr = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        // Create Assets
        new SuperRareToken();
        SuperRareV2 srv2 = new SuperRareV2("SuperRareV2", "SUPR");
        new LazySovereignNFTFactory();

        // Create Royalty Registry
        address[] memory creatorImplementations = new address[](1);
        creatorImplementations[0] = address(srv2);
        CreatorRegistry creator = new CreatorRegistry(creatorImplementations);
        RoyaltyRegistry royaltyRegistry = new RoyaltyRegistry(address(creator));

        // Setup Marketplace Settings
        MarketplaceSettingsV1 v1 = new MarketplaceSettingsV1();
        MarketplaceSettingsV2 v2 = new MarketplaceSettingsV2(addr, address(v1));
        MarketplaceSettingsV3 currentSettings = new MarketplaceSettingsV3(addr, address(v2));

        // Setup Space Operator Registry
        SpaceOperatorRegistry spaceOperatorRegistry = new SpaceOperatorRegistry();

        // Setup Payments
        Payments payments = new Payments();

        // Setup Approved Token Registry
        ApprovedTokenRegistry approvedTokenRegistry = new ApprovedTokenRegistry();

        // Deploy the Contract Factory for Spaces
        new RareSpaceNFTContractFactory(currentSettings, spaceOperatorRegistry); 

        // Deploy the Bazaar
        SuperRareMarketplace bazaarMarketplace = new SuperRareMarketplace();
        SuperRareAuctionHouse bazaarAuctionhouse = new SuperRareAuctionHouse();
        SuperRareBazaar bazaar = new SuperRareBazaar();

        // Grant Marketplace Access
        currentSettings.grantMarketplaceAccess(address(bazaar));

        // Init the Bazaar
        address stakingRegistry = vm.envAddress("STAKING_REGISTRY");
        bazaar.initialize(currentSettings, royaltyRegistry, royaltyEngine, bazaarMarketplace, bazaarAuctionhouse, spaceOperatorRegistry, approvedTokenRegistry, payments, stakingRegistry, addr);

        vm.stopBroadcast();
    }
}
