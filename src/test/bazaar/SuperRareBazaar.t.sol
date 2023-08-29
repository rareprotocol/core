// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";

import {ISuperRareBazaar, SuperRareBazaar} from "../../bazaar/SuperRareBazaar.sol";
import {ISuperRareMarketplace, SuperRareMarketplace} from "../../marketplace/SuperRareMarketplace.sol";
import {IMarketplaceSettings} from "rareprotocol/aux/marketplace/IMarketplaceSettings.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IRoyaltyRegistry} from "rareprotocol/aux/registry/interfaces/IRoyaltyRegistry.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";
import {ISpaceOperatorRegistry} from "rareprotocol/aux/registry/interfaces/ISpaceOperatorRegistry.sol";
import {IApprovedTokenRegistry} from "rareprotocol/aux/registry/interfaces/IApprovedTokenRegistry.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";
import {ISuperRareAuctionHouse, SuperRareAuctionHouse} from "../../auctionhouse/SuperRareAuctionHouse.sol";
import {IRareStakingRegistry} from "../../staking/registry/IRareStakingRegistry.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SuperFakeNFT} from "../../test/utils/SuperFakeNFT.sol";
import {TestRare} from "../../test/utils/TestRare.sol";



contract SuperRareBazaarTest is Test {
  TestRare private superRareToken;
  SuperRareMarketplace private superRareMarketplace;
  SuperRareAuctionHouse private superRareAuctionHouse;
  SuperRareBazaar private superRareBazaar;


  address marketplaceSettings = address(0xabadaba1);
  address royaltyRegistry = address(0xabadaba2);
  address royaltyEngine = address(0xabadaba3);
  address spaceOperatorRegistry = address(0xabadaba6);
  address approvedTokenRegistry = address(0xabadaba7);
  address stakingRegistry = address(0xabadaba9);
  address networkBeneficiary = address(0xabadabaa);
  address rewardPool = address(0xcccc);

  address private immutable exploiter = vm.addr(0x123);
  address private immutable exploiter1 = vm.addr(0x231);
  address private immutable bidder = vm.addr(0x321);

  uint256 private constant TARGET_AMOUNT = 249.6 ether;

  uint256 private constant _lengthOfAuction = 1;

  bytes32 private constant SCHEDULED_AUCTION = "SCHEDULED_AUCTION";

  SuperFakeNFT private sfn;

  function setUp() public {
    // Create market, auction, bazaar, and token contracts
    superRareToken = new TestRare();
    superRareMarketplace = new SuperRareMarketplace();
    superRareAuctionHouse = new SuperRareAuctionHouse();
    superRareBazaar = new SuperRareBazaar();

    // Deploy Payments
    Payments payments = new Payments();

    // Initialize the bazaar
    superRareBazaar.initialize(marketplaceSettings, royaltyRegistry, royaltyEngine, address(superRareMarketplace), address(superRareAuctionHouse), spaceOperatorRegistry, approvedTokenRegistry, address(payments), stakingRegistry, networkBeneficiary);

    SuperFakeNFT _sfn = new SuperFakeNFT(address(superRareBazaar));
    sfn = _sfn;

    sfn.mint(exploiter, 1);
    superRareToken.transfer(bidder, 300 ether);
    vm.deal(address(superRareBazaar), 300 ether);

    vm.prank(bidder);
    superRareToken.approve(address(superRareBazaar), type(uint256).max);

    vm.prank(exploiter);
    sfn.setApprovalForAll(address(superRareBazaar), true);

    vm.prank(exploiter1);
    sfn.setApprovalForAll(address(superRareBazaar), true);

    // etch code into these so we can stub out methods. Need some
    vm.etch(marketplaceSettings, address(superRareToken).code);
    vm.etch(stakingRegistry, address(superRareToken).code);
    vm.etch(royaltyRegistry, address(superRareToken).code);
    vm.etch(royaltyEngine, address(superRareToken).code);
    vm.etch(spaceOperatorRegistry, address(superRareToken).code);
    vm.etch(approvedTokenRegistry, address(superRareToken).code);
  }

  function test_auctions_with_eth_sucess() public {

  }

  function test_auctions_with_erc20_success() public {

  }

  function test_convert_offer_currency_exploit() external {

    /*///////////////////////////////////////////////////
                        Mock Calls
    ///////////////////////////////////////////////////*/
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getRewardAccumulatorAddressForUser.selector, exploiter1),
      abi.encode(address(0))
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, TARGET_AMOUNT),
      abi.encode((TARGET_AMOUNT * 3) / 100)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, TARGET_AMOUNT),
      abi.encode(0)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getMarketplaceFeePercentage.selector),
      abi.encode(3)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getMarketplaceMaxValue.selector),
      abi.encode(type(uint256).max)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, TARGET_AMOUNT),
      abi.encode((TARGET_AMOUNT * 3) / 100)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, address(sfn), 1),
      abi.encode(false)
    );
    vm.mockCall(
      spaceOperatorRegistry,
      abi.encodeWithSelector(ISpaceOperatorRegistry.isApprovedSpaceOperator.selector, exploiter1),
      abi.encode(false)
    );
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, address(superRareToken)),
      abi.encode(true)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getERC721ContractPrimarySaleFeePercentage.selector, address(sfn)),
      abi.encode(15)
    );
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, address(sfn)),
      abi.encode()
    );

    /*///////////////////////////////////////////////////
                        Test
    ///////////////////////////////////////////////////*/
    configureAuction();

    skip(12); //~about 1 block
    vm.expectRevert();
    superRareBazaar.settleAuction(address(sfn), 1);
  }


  /*//////////////////////////////////////////////////////////////////////////
                          Helper Functions
  //////////////////////////////////////////////////////////////////////////*/

  // Receive function for test contract to be sent value
  receive() external payable {
    console2.log("Amount Recieved by Attacker:", msg.value);
  }
  
  // Configure the auction
  function configureAuction() internal {
    // Setup the Offer and convert it to an auction 
    createOfferAndConvertToAuction();

    address payable[] memory _splitAddresses = new address payable[](1);
    _splitAddresses[0] = payable(address(this));

    uint8[] memory _splitRatios = new uint8[](1);
    _splitRatios[0] = 100;

    //@exploit: Assumes all NFTs follows the ERC-721 spec
    vm.prank(exploiter);
    IERC721(sfn).transferFrom(exploiter, exploiter1, 1);

    //@exploit: Overwrites previously set auction with a new Currency (ETH). Keeps the same bid
    vm.prank(exploiter1);
    vm.expectRevert();
    superRareBazaar.configureAuction(
      SCHEDULED_AUCTION,
      address(sfn),
      1,
      TARGET_AMOUNT,
      address(0),
      _lengthOfAuction,
      block.timestamp + 1,
      _splitAddresses,
      _splitRatios
    );
  }

  function createOfferAndConvertToAuction() internal {
    createOffer();

    address payable[] memory _splitAddresses = new address payable[](1);
    _splitAddresses[0] = payable(address(this));

    uint8[] memory _splitRatios = new uint8[](1);
    _splitRatios[0] = 100;

    vm.prank(exploiter);
    superRareBazaar.convertOfferToAuction(
      address(sfn),
      1,
      address(superRareToken),
      TARGET_AMOUNT,
      _lengthOfAuction,
      _splitAddresses,
      _splitRatios
    );
  }

  function createOffer() internal {
    console2.log("Before Attack: SuperRareBazaar ETH Balance:", address(superRareBazaar).balance);

    //@exploit: Create an Offer using a custom NFT and the superRareToken as Currency
    vm.prank(bidder);
    superRareBazaar.offer(address(sfn), 1, address(superRareToken), TARGET_AMOUNT, true);
  }


}