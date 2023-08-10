// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "rareprotocol/aux/marketplace/MarketplaceSettingsV3.sol";

import "../../src/auctionhouse/SuperRareAuctionHouse.sol";
import "../../src/marketplace/SuperRareMarketplace.sol";
import "../../src/bazaar/SuperRareBazaar.sol";

/////////////////////////////////////////////////////////////////////////
// Post Deployment Instructions
/////////////////////////////////////////////////////////////////////////
// Grant new marketplace settings the mark token role for old marketplace settings

contract BazaarStakingPayoutUpdate is Script {
  function run() external {
    vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

    // Deploy Marketplace Settings
    MarketplaceSettingsV3 mksv3 = new MarketplaceSettingsV3(
      vm.addr(vm.envUint("PRIVATE_KEY")),
      vm.envAddress("OLD_MARKETPLACE_SETTINGS")
    );
    // Set Staking percentage
    mksv3.setStakingFeePercentage(1);
    
    // Grant bazaar contract mark token role
    mksv3.grantMarketplaceAccess(vm.envAddress("BAZAAR_ADDRESS"));

    SuperRareBazaar bazaar = SuperRareBazaar(vm.envAddress("BAZAAR_ADDRESS"));

    // Set new marketplace settings in bazaar
    bazaar.setMarketplaceSettings(address(mksv3));

    // Set staking registry
    bazaar.setStakingRegistry(vm.envAddress("STAKING_REGISTRY"));

    // Deploy and set AuctionHouse logic contract
    SuperRareAuctionHouse auctionHouse = new SuperRareAuctionHouse();
    bazaar.setSuperRareAuctionHouse(address(auctionHouse));

    // Deploy and set Marketplace logic contract
    SuperRareMarketplace marketplace = new SuperRareMarketplace();
    bazaar.setSuperRareMarketplace(address(marketplace));
  }
}
