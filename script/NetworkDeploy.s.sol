// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/marketplace/MarketplaceSettingsV1.sol";
import "../src/marketplace/MarketplaceSettingsV2.sol";
import "../src/marketplace/MarketplaceSettingsV3.sol";
import "../src/marketplace/SuperRareMarketplace.sol";
import "../src/auctionhouse/SuperRareAuctionHouse.sol";
import "../src/bazaar/SuperRareBazaar.sol";
import "../src/registry/SpaceOperatorRegistry.sol";
import "../src/registry/ApprovedTokenRegistry.sol";
import "../src/payments/Payments.sol";
import "../src/registry/CreatorRegistry.sol";
import "../src/registry/RoyaltyRegistry.sol";
import "../src/token/ERC721/superrare/SuperRareV2.sol";
import "../src/token/ERC20/SuperRareGovToken.sol";
import "../src/token/ERC721/sovereign/lazy/LazySovereignNFTFactory.sol";
import "../src/token/ERC721/spaces/RareSpaceNFTContractFactory.sol";
import "royalty-registry/RoyaltyEngineV1.sol";

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
        RoyaltyEngineV1 royaltyEngine = new RoyaltyEngineV1(addr);

        // Setup Marketplace Settings
        MarketplaceSettingsV1 v1 = new MarketplaceSettingsV1();
        MarketplaceSettingsV2 v2 = new MarketplaceSettingsV2(addr, address(v1));
        MarketplaceSettingsV3 currentSettings = new MarketplaceSettingsV3(addr, address(v2));

        // // Setup Space Operator Registry
        SpaceOperatorRegistry spaceOperatorRegistry = new SpaceOperatorRegistry();

        // // Setup Payments
        Payments payments = new Payments();

        // // Setup Approved Token Registry
        ApprovedTokenRegistry approvedTokenRegistry = new ApprovedTokenRegistry();

        // // Deploy the Contract Factory for Spaces
        new RareSpaceNFTContractFactory(address(currentSettings), address(spaceOperatorRegistry)); 

        // // Deploy the Bazaar
        SuperRareMarketplace bazaarMarketplace = new SuperRareMarketplace();
        SuperRareAuctionHouse bazaarAuctionhouse = new SuperRareAuctionHouse();
        SuperRareBazaar bazaar = new SuperRareBazaar();

        // // Grant Marketplace Access
        currentSettings.grantMarketplaceAccess(address(bazaar));

        // // Init the Bazaar
        address stakingRegistry = vm.envAddress("STAKING_REGISTRY");
        bazaar.initialize(address(currentSettings), address(royaltyRegistry), address(royaltyEngine), address(bazaarMarketplace), address(bazaarAuctionhouse), address(spaceOperatorRegistry), address(approvedTokenRegistry), address(payments), stakingRegistry, addr);

        vm.stopBroadcast();
    }
}
