// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IMarketplaceSettings} from "rareprotocol/aux/marketplace/IMarketplaceSettings.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IRoyaltyRegistry} from "rareprotocol/aux/registry/interfaces/IRoyaltyRegistry.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";
import {ISpaceOperatorRegistry} from "rareprotocol/aux/registry/interfaces/ISpaceOperatorRegistry.sol";
import {IApprovedTokenRegistry} from "rareprotocol/aux/registry/interfaces/IApprovedTokenRegistry.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {MarketUtils} from "../../utils/MarketUtils.sol";
import {MarketConfig} from "../../utils/structs/MarketConfig.sol";
import {IRareStakingRegistry} from "../../staking/registry/IRareStakingRegistry.sol";
import {RareCollectionMarket} from "../../collection/RareCollectionMarket.sol";
import {IRareCollectionMarket} from "../../collection/IRareCollectionMarket.sol";

contract TestCurrency is ERC20 {
  constructor() ERC20("Currency", "CUR") {
    _mint(msg.sender, 1_000_000_000 ether);
  }
}


contract TestRareCollectionMarket is Test {
  RareCollectionMarket market;
  TestCurrency currency;

  address deployer = address(0xabadabab);
  address alice = address(0xbeef);
  address bob = address(0xcafe);
  address charlie = address(0xdead);
  address stakingSettings = address(0xabadaba0);
  address marketplaceSettings = address(0xabadaba1);
  address royaltyRegistry = address(0xabadaba2);
  address royaltyEngine = address(0xabadaba3);
  address spaceOperatorRegistry = address(0xabadaba6);
  address approvedTokenRegistry = address(0xabadaba7);
  address stakingRegistry = address(0xabadaba9);
  address networkBeneficiary = address(0xabadabaa);

  address originContract = address(0xaaaa);
  address zeroAddress = address(0);
  uint256 tokenId = 1;
  uint256 amount = 1 ether;
  uint8 marketplaceFeePercentage = 3;

  address currencyAddress;

  function setUp() public {
    // Deploy TestCurrency
    currency = new TestCurrency();
    currencyAddress = address(currency);

    deal(deployer, 100 ether);
    deal(alice, 100 ether);
    deal(bob, 100 ether);
    deal(charlie, 100 ether);

    currency.transfer(alice, 1000000 ether);
    currency.transfer(bob, 1000000 ether);
    currency.transfer(charlie, 1000000 ether);

    vm.startPrank(deployer);
    market = new RareCollectionMarket();
    market.initialize(
      networkBeneficiary,
      marketplaceSettings,
      spaceOperatorRegistry,
      royaltyEngine,
      address(new Payments()),
      approvedTokenRegistry,
      stakingSettings,
      stakingRegistry
    );

    vm.etch(marketplaceSettings, address(market).code);
    vm.etch(stakingSettings, address(market).code);
    vm.etch(stakingRegistry, address(market).code);
    vm.etch(royaltyRegistry, address(market).code);
    vm.etch(royaltyEngine, address(market).code);
    vm.etch(spaceOperatorRegistry, address(market).code);
    vm.etch(approvedTokenRegistry, address(market).code);
    vm.etch(originContract, address(market).code);

    vm.stopPrank();
  }

  function testMakeCollectionOffer() public {
    mockPayout(amount, charlie);

    vm.startPrank(alice);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();
    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionOffer memory offer = market.getCollectionOffer(originContract, alice);
    if (offer.currencyAddress != zeroAddress) {
      emit log_named_address("Expected: currencyAddress", zeroAddress);
      emit log_named_address("Actual: currencyAddress", offer.currencyAddress);
      revert("incorrect currency address");
    }

    if (offer.amount != amount) {
      emit log_named_uint("Expected: amount", amount);
      emit log_named_uint("Actual: amount", offer.amount);
      revert("incorrect amount");
    }

    if (offer.marketplaceFee != marketplaceFeePercentage) {
      emit log_named_uint("Expected: marketplaceFee", marketplaceFeePercentage);
      emit log_named_uint("Actual: marketplaceFee", offer.marketplaceFee);
      revert("incorrect marketplace fee");
    }
  }

  function testMakeCollectionOfferCurrencyAddressNotApproved() public {
    mockPayout(amount, charlie);
    // mock isApprovedToken
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, currencyAddress),
      abi.encode(false)
    );

    vm.startPrank(alice);
    vm.expectRevert(bytes("Not approved currency"));
    market.makeCollectionOffer(originContract, currencyAddress, amount);
    vm.stopPrank();
  }

  function testMakeCollectionOfferAmountIsZero() public {
    // Call the makeCollectionOffer function with an amount of zero
    vm.startPrank(alice);
    vm.expectRevert(IRareCollectionMarket.AmountCantBeZero.selector);
    market.makeCollectionOffer(originContract, zeroAddress, 0);
    vm.stopPrank();
  }

  function testMakeCollectionOfferSenderDoesNotHaveEnoughApprovedCurrency() public {
    mockPayout(amount, charlie);  
    // mock isApprovedToken
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, currencyAddress),
      abi.encode(true)
    );

    // Call the makeCollectionOffer function with an amount greater than the approved amount for the sender
    vm.startPrank(alice);
    vm.expectRevert(bytes("sender needs to approve marketplace for currency"));
    market.makeCollectionOffer(originContract, currencyAddress, amount);
    vm.stopPrank();
  }

  function testUpdatingExistingCollectionOfferDifferentCurrency() public {
    mockPayout(amount, charlie);
    // mock IApprovedTokenRegistry.isApprovedToken
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, currencyAddress),
      abi.encode(true)
    );


    // Make an initial collection offer
    vm.startPrank(alice);
    currency.increaseAllowance(address(market), 100 ether);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    // // Call the makeCollectionOffer function again with the same origin contract but different currency address and amount
    vm.startPrank(alice);
    market.makeCollectionOffer(originContract, currencyAddress, amount);
    vm.stopPrank();

    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionOffer memory offer = market.getCollectionOffer(originContract, alice);
    if (offer.currencyAddress != currencyAddress) {
      emit log_named_address("Expected: currencyAddress", currencyAddress);
      emit log_named_address("Actual: currencyAddress", offer.currencyAddress);
      revert("incorrect currency address");
    }

    if (offer.amount != amount) {
      emit log_named_uint("Expected: amount", amount);
      emit log_named_uint("Actual: amount", offer.amount);
      revert("incorrect amount");
    }

    if (offer.marketplaceFee != marketplaceFeePercentage) {
      emit log_named_uint("Expected: marketplaceFee", marketplaceFeePercentage);
      emit log_named_uint("Actual: marketplaceFee", offer.marketplaceFee);
      revert("incorrect marketplace fee");
    }
  }

  function testIncreaseCollectionOffer() public {
    mockPayout(amount, charlie);
    uint256 increasedAmount = amount + 1 ether;
    // mock IApprovedTokenRegistry.isApprovedToken
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, currencyAddress),
      abi.encode(true)
    );

    // Make an initial collection offer
    vm.startPrank(alice);
    currency.increaseAllowance(address(market), 100 ether);
    market.makeCollectionOffer(originContract, currencyAddress, amount);
    vm.stopPrank();

    // // Call the makeCollectionOffer function again with the same origin contract but different currency address and amount
    vm.startPrank(alice);
    mockPayout(increasedAmount, charlie);
    market.makeCollectionOffer(originContract, currencyAddress, increasedAmount);
    vm.stopPrank();

    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionOffer memory offer = market.getCollectionOffer(originContract, alice);
    if (offer.currencyAddress != currencyAddress) {
      emit log_named_address("Expected: currencyAddress", currencyAddress);
      emit log_named_address("Actual: currencyAddress", offer.currencyAddress);
      revert("incorrect currency address");
    }

    if (offer.amount != increasedAmount) {
      emit log_named_uint("Expected: amount", increasedAmount);
      emit log_named_uint("Actual: amount", offer.amount);
      revert("incorrect amount");
    }

    if (offer.marketplaceFee != marketplaceFeePercentage) {
      emit log_named_uint("Expected: marketplaceFee", marketplaceFeePercentage);
      emit log_named_uint("Actual: marketplaceFee", offer.marketplaceFee);
      revert("incorrect marketplace fee");
    }
  }

  function testDecreaseCollectionOffer() public {
    mockPayout(amount, charlie);
    uint256 decreasedAmount = amount - 0.5 ether;
    // mock IApprovedTokenRegistry.isApprovedToken
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, currencyAddress),
      abi.encode(true)
    );


    // Make an initial collection offer
    vm.startPrank(alice);
    currency.increaseAllowance(address(market), 100 ether);
    market.makeCollectionOffer(originContract, currencyAddress, amount);
    vm.stopPrank();

    // // Call the makeCollectionOffer function again with the same origin contract but different currency address and amount
    vm.startPrank(alice);
    mockPayout(decreasedAmount, charlie);
    market.makeCollectionOffer(originContract, currencyAddress, decreasedAmount);
    vm.stopPrank();

    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionOffer memory offer = market.getCollectionOffer(originContract, alice);
    if (offer.currencyAddress != currencyAddress) {
      emit log_named_address("Expected: currencyAddress", currencyAddress);
      emit log_named_address("Actual: currencyAddress", offer.currencyAddress);
      revert("incorrect currency address");
    }

    if (offer.amount != decreasedAmount) {
      emit log_named_uint("Expected: amount", decreasedAmount);
      emit log_named_uint("Actual: amount", offer.amount);
      revert("incorrect amount");
    }

    if (offer.marketplaceFee != marketplaceFeePercentage) {
      emit log_named_uint("Expected: marketplaceFee", marketplaceFeePercentage);
      emit log_named_uint("Actual: marketplaceFee", offer.marketplaceFee);
      revert("incorrect marketplace fee");
    }
  }

  function testAcceptCollectionOffer() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );


    vm.startPrank(charlie);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    market.acceptCollectionOffer(charlie, originContract, tokenId, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testAcceptCollectionOfferFailOnSplits() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );


    vm.startPrank(charlie);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    address payable[] memory splitAddrs = new address payable[](2);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(bytes("checkSplits::Splits and ratios must be equal"));
    market.acceptCollectionOffer(charlie, originContract, tokenId, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testAcceptCollectionOfferFailNoOffer() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IRareCollectionMarket.NoOfferExistsForBuyer.selector, originContract, charlie)
    );
    market.acceptCollectionOffer(charlie, originContract, tokenId, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testAcceptCollectionOfferFailSenderNotOwner() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(bob));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );


    vm.startPrank(charlie);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(bytes("sender must be the token owner"));
    market.acceptCollectionOffer(charlie, originContract, tokenId, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testAcceptCollectionOfferFailOwnerMarketplaceNotApproved() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(false));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );


    vm.startPrank(charlie);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(bytes("owner must have approved contract"));
    market.acceptCollectionOffer(charlie, originContract, tokenId, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testAcceptCollectionOfferFailIncorrectAmount() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );


    vm.startPrank(charlie);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(abi.encodeWithSelector(IRareCollectionMarket.IncorrectAmount.selector, amount, amount + 1));
    market.acceptCollectionOffer(charlie, originContract, tokenId, zeroAddress, amount + 1, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testAcceptCollectionOfferFailCurrencyMismatch() public {
    mockPayout(amount, alice);
    // Mocks for: MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());
    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );


    vm.startPrank(charlie);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(charlie);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(
      abi.encodeWithSelector(IRareCollectionMarket.CurrencyMismatch.selector, currencyAddress, zeroAddress)
    );
    market.acceptCollectionOffer(charlie, originContract, tokenId, currencyAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testCancelCollectionOffer() public {
    mockPayout(amount, charlie);

    vm.startPrank(alice);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    market.cancelCollectionOffer(originContract);
    vm.stopPrank();
    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionOffer memory offer = market.getCollectionOffer(originContract, alice);
    if (offer.currencyAddress != zeroAddress) {
      emit log_named_address("Expected: currencyAddress", zeroAddress);
      emit log_named_address("Actual: currencyAddress", offer.currencyAddress);
      revert("incorrect currency address");
    }

    if (offer.amount != 0) {
      emit log_named_uint("Expected: amount", 0);
      emit log_named_uint("Actual: amount", offer.amount);
      revert("incorrect amount");
    }

    if (offer.marketplaceFee != 0) {
      emit log_named_uint("Expected: marketplaceFee", 0);
      emit log_named_uint("Actual: marketplaceFee", offer.marketplaceFee);
      revert("incorrect marketplace fee");
    }
  }

  function testCancelCollectionOfferFailToCancelAnothersOffer() public {
    mockPayout(amount, charlie);

    vm.startPrank(alice);
    market.makeCollectionOffer{value: amount + ((amount * 3) / 100)}(originContract, zeroAddress, amount);
    vm.stopPrank();
    vm.startPrank(charlie);
    market.cancelCollectionOffer(originContract);
    vm.stopPrank();
    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionOffer memory offer = market.getCollectionOffer(originContract, alice);
    if (offer.amount != amount) {
      emit log_named_uint("Expected: amount", amount);
      emit log_named_uint("Actual: amount", offer.amount);
      revert("incorrect amount");
    }
  }

  function testSetCollectionSalePrice() public {
    mockPayout(amount, alice);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
    IRareCollectionMarket.CollectionSalePrice memory salePrice = market.getCollectionSalePrice(originContract, alice);
    if (salePrice.amount != amount) {
      emit log_named_uint("Expected: amount", amount);
      emit log_named_uint("Actual: amount", salePrice.amount);
      revert("incorrect amount");
    }
  }

  function testSetCollectionSalePriceFailUnapprovedCurrency() public {
    mockPayout(amount, alice);

    // mock isApprovedToken
    vm.mockCall(
      approvedTokenRegistry,
      abi.encodeWithSelector(IApprovedTokenRegistry.isApprovedToken.selector, currencyAddress),
      abi.encode(false)
    );

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(bytes("Not approved currency"));
    market.setCollectionSalePrice(originContract, currencyAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testSetCollectionSalePriceFailNFTContractNotApproved() public {
    mockPayout(amount, alice);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(false));

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(bytes("owner must have approved contract"));
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testSetCollectionSalePriceFailOnSplits() public {
    mockPayout(amount, alice);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    address payable[] memory splitAddrs = new address payable[](2);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(bytes("checkSplits::Splits and ratios must be equal"));
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testSetCollectionSalePriceFailZeroAmount() public {
    mockPayout(amount, alice);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    vm.expectRevert(IRareCollectionMarket.AmountCantBeZero.selector);
    market.setCollectionSalePrice(originContract, zeroAddress, 0, splitAddrs, splitRatios);
    vm.stopPrank();
  }

  function testCancelCollectionSalePrice() public {
    mockPayout(amount, alice);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;

    vm.startPrank(alice);
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    market.cancelCollectionSalePrice(originContract);
    vm.stopPrank();
    IRareCollectionMarket.CollectionSalePrice memory salePrice = market.getCollectionSalePrice(originContract, alice);
    if (salePrice.amount != 0) {
      emit log_named_uint("Expected: amount", 0);
      emit log_named_uint("Actual: amount", salePrice.amount);
      revert("incorrect amount");
    }
  }

  function testCancelCollectionSalePriceFailCancelAnothersSalePrice() public {
    mockPayout(amount, alice);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    vm.startPrank(alice);
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();

    vm.startPrank(charlie);
    market.cancelCollectionSalePrice(originContract);
    vm.stopPrank();
    // Assert that the collection offer is recorded correctly
    IRareCollectionMarket.CollectionSalePrice memory salePrice = market.getCollectionSalePrice(originContract, alice);
    if (salePrice.amount != amount) {
      emit log_named_uint("Expected: amount", amount);
      emit log_named_uint("Actual: amount", salePrice.amount);
      revert("incorrect amount");
    }
  }

  function testBuyFromCollection() public {
    mockPayout(amount, alice);
    mockPayout(amount, charlie);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.ownerOf(_tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());

    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;

    vm.startPrank(alice);
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();

    vm.startPrank(charlie);
    market.buyFromCollection{value:amount + (amount * 3 / 100)}(originContract, tokenId, zeroAddress, amount);
    vm.stopPrank();

  }

  function testBuyFromCollectionFailNotApproved() public {
    mockPayout(amount, alice);
    mockPayout(amount, charlie);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(false));

    // Mocks for: erc721.ownerOf(_tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;

    vm.startPrank(alice);
    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();

    vm.startPrank(charlie);
    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(false));
    vm.expectRevert(bytes("owner must have approved contract"));
    market.buyFromCollection{value:amount + (amount * 3 / 100)}(originContract, tokenId, zeroAddress, amount);
    vm.stopPrank();

  }

  function testBuyFromCollectionFailNoSalePrice() public {
    mockPayout(amount, alice);
    mockPayout(amount, charlie);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.ownerOf(_tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());

    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;

    vm.startPrank(charlie);
    vm.expectRevert(abi.encodeWithSelector(IRareCollectionMarket.SalePriceDoesntExist.selector, alice, originContract));
    market.buyFromCollection{value:amount + (amount * 3 / 100)}(originContract, tokenId, zeroAddress, amount);
    vm.stopPrank();
  }

  function testBuyFromCollectionFailCurrencyMismatch() public {
    mockPayout(amount, alice);
    mockPayout(amount, charlie);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.ownerOf(_tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());

    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;

    vm.startPrank(alice);
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();

    vm.startPrank(charlie);
    vm.expectRevert(abi.encodeWithSelector(IRareCollectionMarket.CurrencyMismatch.selector, currencyAddress, zeroAddress));
    market.buyFromCollection(originContract, tokenId, currencyAddress, amount);
    vm.stopPrank();

  }
  function testBuyFromCollectionFailIncorrectAmount() public {
    mockPayout(amount, alice);
    mockPayout(amount, charlie);

    // Mocks for: MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.isApprovedForAll.selector, alice), abi.encode(true));

    // Mocks for: erc721.ownerOf(_tokenId);
    vm.mockCall(originContract, abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId), abi.encode(alice));

    // Mocks for: erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);
    // cast sig "safeTransferFrom(address from, address to, uint256 tokenId)" == 0x42842e0e
    vm.mockCall(originContract, abi.encodeWithSelector(0x42842e0e, alice, charlie, tokenId), abi.encode());

    // Mocks for: marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.markERC721Token.selector, originContract, tokenId, true),
      abi.encode()
    );

    address payable[] memory splitAddrs = new address payable[](1);
    splitAddrs[0] = payable(alice);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;

    vm.startPrank(alice);
    market.setCollectionSalePrice(originContract, zeroAddress, amount, splitAddrs, splitRatios);
    vm.stopPrank();

    vm.startPrank(charlie);
    uint256 incorrectAmount = amount + 1 ether;
    mockPayout(incorrectAmount, charlie);
    vm.expectRevert(abi.encodeWithSelector(IRareCollectionMarket.IncorrectAmount.selector, amount, incorrectAmount));
    market.buyFromCollection{value:incorrectAmount + (incorrectAmount * 3 / 100)}(originContract, tokenId, zeroAddress, incorrectAmount);
    vm.stopPrank();

  }

  function mockPayout(uint256 _amount, address _seller) internal {
    // setup getStakingInfoForUser call -- 3%
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getStakingInfoForUser.selector, _seller),
      abi.encode(IRareStakingRegistry.Info("", "", address(0), address(0)))
    );

    // setup calculateMarketplacePayoutFee call -- 3%
    vm.mockCall(
      stakingSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, _amount),
      abi.encode((_amount * 3) / 100)
    );

    // setup calculateStakingFee call -- 3%
    vm.mockCall(
      stakingSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, _amount),
      abi.encode(0)
    );

    // setup calculateMarketplaceFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, _amount),
      abi.encode((_amount * 3) / 100)
    );

    // setup getMarketplaceFeePercentage call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getMarketplaceFeePercentage.selector),
      abi.encode(marketplaceFeePercentage)
    );

    // setup has hasERC721TokenSold -- false
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, originContract, 1),
      abi.encode(false)
    );
    // setup has isApprovedSpaceOperator -- false
    vm.mockCall(
      spaceOperatorRegistry,
      abi.encodeWithSelector(ISpaceOperatorRegistry.isApprovedSpaceOperator.selector, _seller),
      abi.encode(false)
    );

    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getERC721ContractPrimarySaleFeePercentage.selector, originContract),
      abi.encode(15)
    );

  }
}
