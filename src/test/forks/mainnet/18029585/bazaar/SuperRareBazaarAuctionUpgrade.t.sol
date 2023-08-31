// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";

import {ISuperRareBazaar, SuperRareBazaar} from "../../../../../bazaar/SuperRareBazaar.sol";
import {ISuperRareMarketplace, SuperRareMarketplace} from "../../../../../marketplace/SuperRareMarketplace.sol";
import {ISuperRareAuctionHouse, SuperRareAuctionHouse} from "../../../../../auctionhouse/SuperRareAuctionHouse.sol";
import {IRareStakingRegistry} from "../../../../../staking/registry/IRareStakingRegistry.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SuperFakeNFT} from "../../../../../test/utils/SuperFakeNFT.sol";
import {TestRare} from "../../../../../test/utils/TestRare.sol";

contract SuperRareBazaarAuctionUpgrade is Test {
  // Constant auction length for testing
  uint256 private constant LENGTH_OF_AUCTION = 12;

  // Auction Type for testing
  bytes32 private constant SCHEDULED_AUCTION = "SCHEDULED_AUCTION";

  // SuperRareToken Contract
  address private rare;

  // Bazaar Contract
  SuperRareBazaar private bazaar;

  // Updated Auction Contract
  SuperRareAuctionHouse private auctionHouse;

  // Contract Admin
  address private admin;

  // Bidder
  address private bidder;

  // Auction Creator
  address private auctionCreator;

  // NFT Contract
  IERC721 private nftContract;

  // NFT Token ID
  uint256 private tokenId;

  /*///////////////////////////////////////////////////
                      Setup
  ///////////////////////////////////////////////////*/
  function setUp() public {
    // Check that it is mainnet and the block is correct
    require(
      block.number == 18029585,
      "This test is intended to be run against a mainnet fork at block: 18029585. Please run using: forge test --fork-url <main-api-url> --fork-block-number 18029585"
    );

    // EOAs
    admin = address(0x860a80d33E85e97888F1f0C75c6e5BBD60b48DA9);
    bidder = address(0x09F8b58438C026564CbC23d54fBa39C7237D827A);
    auctionCreator = address(0xec8c1050B45789f9ee4D09dCC7D64aAF9e233338);
    vm.deal(admin, 10 ether);
    vm.deal(auctionCreator, 10 ether);
    vm.deal(bidder, 10 ether);

    // Contracts
    rare = address(0xba5BDe662c17e2aDFF1075610382B9B691296350);
    bazaar = SuperRareBazaar(address(0x6D7c44773C52D396F43c2D511B81aa168E9a7a42));
    auctionHouse = new SuperRareAuctionHouse();
    nftContract = IERC721(address(0xE418c30CA2ECD3C046122ea0FaF95a6B9DA97191));
    tokenId = 137;

    // Set Approval for Bazaar
    vm.prank(auctionCreator);
    nftContract.setApprovalForAll(address(bazaar), true);
  }

  /*///////////////////////////////////////////////////
                      Tests
  ///////////////////////////////////////////////////*/

  // Test that a running auction can still settle
  function test_running_auction_settles_after_upgrade() public {
    address payable[] memory splitAddresses = new address payable[](1);
    splitAddresses[0] = payable(auctionCreator);

    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    // Create an auction
    vm.prank(auctionCreator);
    bazaar.configureAuction(
      SCHEDULED_AUCTION,
      address(nftContract),
      tokenId,
      1 ether,
      address(0),
      LENGTH_OF_AUCTION,
      block.timestamp + 1,
      splitAddresses,
      splitRatios
    );

    // Auction begins
    vm.warp(block.timestamp + 2);

    // Bid
    vm.prank(bidder);
    bazaar.bid{value: 1.03 ether}(address(nftContract), tokenId, address(0), 1 ether);

    // Upgrade happens
    runBazaarUpgrade();

    // Auction ends
    vm.warp(block.timestamp + 100*LENGTH_OF_AUCTION + 1);

    // Auction settled
    bazaar.settleAuction(address(nftContract), tokenId);
  }
  function test_create_auction_after_upgrade() public {
    // Upgrade happens
    runBazaarUpgrade();

    address payable[] memory splitAddresses = new address payable[](1);
    splitAddresses[0] = payable(auctionCreator);

    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    // Create an auction
    vm.prank(auctionCreator);
    bazaar.configureAuction(
      SCHEDULED_AUCTION,
      address(nftContract),
      tokenId,
      1 ether,
      address(0),
      LENGTH_OF_AUCTION,
      block.timestamp + 1,
      splitAddresses,
      splitRatios
    );

    // Auction begins
    vm.warp(block.timestamp + 2);

    // Bid
    vm.prank(bidder);
    bazaar.bid{value: 1.03 ether}(address(nftContract), tokenId, address(0), 1 ether);


    // Auction ends
    vm.warp(block.timestamp + 100*LENGTH_OF_AUCTION + 1);

    // Auction settled
    bazaar.settleAuction(address(nftContract), tokenId);
  }

  /*///////////////////////////////////////////////////
                      Helper Functions
  ///////////////////////////////////////////////////*/

  // Function to run the upgrade
  function runBazaarUpgrade() public {
    vm.startPrank(admin);
    bazaar.setSuperRareAuctionHouse(address(auctionHouse));
    vm.stopPrank();
  }
}
