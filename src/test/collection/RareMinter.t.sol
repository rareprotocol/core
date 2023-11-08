// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IMarketplaceSettings} from "rareprotocol/aux/marketplace/IMarketplaceSettings.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IRoyaltyRegistry} from "rareprotocol/aux/registry/interfaces/IRoyaltyRegistry.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";
import {ISpaceOperatorRegistry} from "rareprotocol/aux/registry/interfaces/ISpaceOperatorRegistry.sol";
import {IRareStakingRegistry} from "../../staking/registry/IRareStakingRegistry.sol";
import {IApprovedTokenRegistry} from "rareprotocol/aux/registry/interfaces/IApprovedTokenRegistry.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {MarketUtils} from "../../utils/MarketUtils.sol";
import {MarketConfig} from "../../utils/structs/MarketConfig.sol";
import {RareMinter} from "../../collection/RareMinter.sol";
import {IRareMinter} from "../../collection/IRareMinter.sol";
import {IERC721Mint} from "../../collection/IERC721Mint.sol";

contract TestCurrency is ERC20 {
  constructor() ERC20("Currency", "CUR") {
    _mint(msg.sender, 1_000_000_000 ether);
  }
}

contract TestERC721 is ERC721, IERC721Mint, Ownable {
  uint256 private tokenCount;

  constructor() ERC721("TestERC721", "TEST") {}

  function mintTo(address _receiver) external returns (uint256) {
    tokenCount++;
    _mint(_receiver, tokenCount);
    return tokenCount;
  }
}

contract TestRareMinter is Test {
  RareMinter rareMinter;
  TestCurrency currency;
  TestERC721 testErc721;

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

  address zeroAddress = address(0);
  uint256 tokenId = 1;
  uint8 marketplaceFeePercentage = 3;

  address currencyAddress;

  function setUp() public {
    vm.startPrank(deployer);
    // Deploy Test Assets
    currency = new TestCurrency();
    testErc721 = new TestERC721();
    currencyAddress = address(currency);

    deal(deployer, 100 ether);
    deal(alice, 100 ether);
    deal(bob, 100 ether);
    deal(charlie, 100 ether);

    currency.transfer(alice, 1000000 ether);
    currency.transfer(bob, 1000000 ether);
    currency.transfer(charlie, 1000000 ether);

    rareMinter = new RareMinter();
    rareMinter.initialize(
      networkBeneficiary,
      marketplaceSettings,
      spaceOperatorRegistry,
      royaltyEngine,
      address(new Payments()),
      approvedTokenRegistry,
      stakingSettings,
      stakingRegistry
    );

    vm.etch(marketplaceSettings, address(rareMinter).code);
    vm.etch(stakingSettings, address(rareMinter).code);
    vm.etch(stakingRegistry, address(rareMinter).code);
    vm.etch(royaltyRegistry, address(rareMinter).code);
    vm.etch(royaltyEngine, address(rareMinter).code);
    vm.etch(spaceOperatorRegistry, address(rareMinter).code);
    vm.etch(approvedTokenRegistry, address(rareMinter).code);

    vm.stopPrank();
  }

  function test_prepareMintDirectSale() public {
    vm.prank(deployer);
    testErc721.transferOwnership(alice);
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;

    // Prep args
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(
      address(testErc721),
      currencyAddress,
      price,
      startTime,
      splitRecipients,
      splitRatios
    );
    vm.stopPrank();

    IRareMinter.DirectSaleConfig memory config = rareMinter.getDirectSaleConfig(address(testErc721));

    if (config.seller != alice) {
      emit log_named_address("Expected: seller", alice);
      emit log_named_address("Actual: seller", config.seller);
      revert("incorrect seller");
    }

    if (config.currencyAddress != currencyAddress) {
      emit log_named_address("Expected: currencyAddress", currencyAddress);
      emit log_named_address("Actual: currencyAddress", config.currencyAddress);
      revert("incorrect currency address");
    }

    if (config.price != price) {
      emit log_named_uint("Expected: price", price);
      emit log_named_uint("Actual: price", config.price);
      revert("incorrect price");
    }

    if (config.startTime != startTime) {
      emit log_named_uint("Expected: startTime", startTime);
      emit log_named_uint("Actual: startTime", config.startTime);
      revert("incorrect startTime");
    }
    if (config.splitRatios[0] != splitRatios[0]) {
      emit log_named_uint("Expected: splitRatios", splitRatios[0]);
      emit log_named_uint("Actual: splitRatios", config.splitRatios[0]);
      revert("incorrect splitRatios");
    }
    if (config.splitRecipients[0] != splitRecipients[0]) {
      emit log_named_address("Expected: splitRecipients", splitRecipients[0]);
      emit log_named_address("Actual: splitRecipients", config.splitRecipients[0]);
      revert("incorrect splitRecipients");
    }
  }

  function test_mintDirectSale_erc20() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    mockPayout(amount, seller);

    vm.prank(deployer);
    testErc721.transferOwnership(alice);
    vm.prank(charlie);
    currency.approve(address(rareMinter), amount + (amount * 3) / 100);
    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(
      address(testErc721),
      currencyAddress,
      price,
      startTime,
      splitRecipients,
      splitRatios
    );
    vm.stopPrank();

    uint256 charlieBalanceBefore = currency.balanceOf(charlie);
    uint256 aliceBalanceBefore = currency.balanceOf(alice);
    // Warp to start time
    vm.warp(block.timestamp + 60);
    vm.startPrank(charlie);
    rareMinter.mintDirectSale(address(testErc721), currencyAddress, price, numMints);
    vm.stopPrank();

    // Check that the token was minted
    address tokenOwner = testErc721.ownerOf(1);
    if (charlie != tokenOwner) {
      emit log_named_address("Expected: tokenOwner", charlie);
      emit log_named_address("Actual: tokenOwner", tokenOwner);
      revert("incorrect tokenOwner");
    }

    // Check Payment
    uint256 charlieBalanceAfter = currency.balanceOf(charlie);
    uint256 actualDifferenceCharlie = charlieBalanceBefore - charlieBalanceAfter;
    uint256 expectedDifferenceCharlie = amount + (amount * 3) / 100;
    if (actualDifferenceCharlie != expectedDifferenceCharlie) {
      emit log_named_uint("Expected: difference ", expectedDifferenceCharlie);
      emit log_named_uint("Actual: difference", actualDifferenceCharlie);
      emit log_named_uint("charlieBalanceBefore", charlieBalanceBefore);
      emit log_named_uint("charlieBalanceAfter", charlieBalanceAfter);
      revert("incorrect  payment for mint");
    }
    uint256 aliceBalanceAfter = currency.balanceOf(alice);
    uint256 actualDifference = aliceBalanceAfter - aliceBalanceBefore;
    uint256 expectedDifference = amount - (amount * 15) / 100;
    if (actualDifference != expectedDifference) {
      emit log_named_uint("Expected: difference ", expectedDifference);
      emit log_named_uint("Actual: difference", actualDifference);
      emit log_named_uint("aliceBalanceBefore", aliceBalanceBefore);
      emit log_named_uint("aliceBalanceAfter", aliceBalanceAfter);
      revert("incorrect  payment for mint");
    }
  }

  function test_mintDirectSale_eth() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    mockPayout(amount, seller);
    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(address(testErc721), address(0), price, startTime, splitRecipients, splitRatios);
    vm.stopPrank();

    uint256 charlieBalanceBefore = charlie.balance;
    uint256 aliceBalanceBefore = alice.balance;
    // Warp to start time
    vm.warp(block.timestamp + 60);
    vm.startPrank(charlie);
    rareMinter.mintDirectSale{value: amount + (amount * 3) / 100}(address(testErc721), address(0), price, numMints);
    vm.stopPrank();

    // Check that the token was minted
    address tokenOwner = testErc721.ownerOf(1);
    if (charlie != tokenOwner) {
      emit log_named_address("Expected: tokenOwner", charlie);
      emit log_named_address("Actual: tokenOwner", tokenOwner);
      revert("incorrect tokenOwner");
    }

    // Check Payment
    uint256 charlieBalanceAfter = charlie.balance;
    uint256 actualDifferenceCharlie = charlieBalanceBefore - charlieBalanceAfter;
    uint256 expectedDifferenceCharlie = amount + (amount * 3) / 100;
    if (actualDifferenceCharlie != expectedDifferenceCharlie) {
      emit log_named_uint("Expected: difference ", expectedDifferenceCharlie);
      emit log_named_uint("Actual: difference", actualDifferenceCharlie);
      emit log_named_uint("charlieBalanceBefore", charlieBalanceBefore);
      emit log_named_uint("charlieBalanceAfter", charlieBalanceAfter);
      revert("incorrect  payment for mint");
    }
    uint256 aliceBalanceAfter = alice.balance;
    uint256 actualDifference = aliceBalanceAfter - aliceBalanceBefore;
    uint256 expectedDifference = amount - (amount * 15) / 100;
    if (actualDifference != expectedDifference) {
      emit log_named_uint("Expected: difference ", expectedDifference);
      emit log_named_uint("Actual: difference", actualDifference);
      emit log_named_uint("aliceBalanceBefore", aliceBalanceBefore);
      emit log_named_uint("aliceBalanceAfter", aliceBalanceAfter);
      revert("incorrect  payment for mint");
    }
  }

  function test_mintDirectSale_hasSold() public {
    // setup has hasERC721TokenSold -- false
    address seller = alice;
    address payable[] memory royaltyReceiverAddrs = new address payable[](1);
    uint256[] memory royaltyAmounts = new uint256[](1);
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    royaltyReceiverAddrs[0] = payable(seller);
    royaltyAmounts[0] = (amount * 10) / 100;
    mockPayout(amount, seller);
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, address(testErc721), 1),
      abi.encode(true)
    );
    // setup has getRoyalty -- 10%
    vm.mockCall(
      royaltyEngine,
      abi.encodeWithSelector(IRoyaltyEngineV1.getRoyalty.selector, testErc721, 1, amount),
      abi.encode(royaltyReceiverAddrs, royaltyAmounts)
    );

    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(address(testErc721), address(0), price, startTime, splitRecipients, splitRatios);
    vm.stopPrank();

    uint256 charlieBalanceBefore = charlie.balance;
    uint256 aliceBalanceBefore = alice.balance;
    // Warp to start time
    vm.warp(block.timestamp + 60);
    vm.startPrank(charlie);
    rareMinter.mintDirectSale{value: amount + (amount * 3) / 100}(address(testErc721), address(0), price, numMints);
    vm.stopPrank();

    // Check that the token was minted
    address tokenOwner = testErc721.ownerOf(1);
    if (charlie != tokenOwner) {
      emit log_named_address("Expected: tokenOwner", charlie);
      emit log_named_address("Actual: tokenOwner", tokenOwner);
      revert("incorrect tokenOwner");
    }

    // Check Payment
    uint256 charlieBalanceAfter = charlie.balance;
    uint256 actualDifferenceCharlie = charlieBalanceBefore - charlieBalanceAfter;
    uint256 expectedDifferenceCharlie = amount + (amount * 3) / 100;
    if (actualDifferenceCharlie != expectedDifferenceCharlie) {
      emit log_named_uint("Expected: difference ", expectedDifferenceCharlie);
      emit log_named_uint("Actual: difference", actualDifferenceCharlie);
      emit log_named_uint("charlieBalanceBefore", charlieBalanceBefore);
      emit log_named_uint("charlieBalanceAfter", charlieBalanceAfter);
      revert("incorrect  payment for mint");
    }
    uint256 aliceBalanceAfter = alice.balance;
    uint256 actualDifference = aliceBalanceAfter - aliceBalanceBefore;
    uint256 expectedDifference = amount;
    if (actualDifference != expectedDifference) {
      emit log_named_uint("Expected: difference ", expectedDifference);
      emit log_named_uint("Actual: difference", actualDifference);
      emit log_named_uint("aliceBalanceBefore", aliceBalanceBefore);
      emit log_named_uint("aliceBalanceAfter", aliceBalanceAfter);
      revert("incorrect  payment for mint");
    }
  }

  function test_mintDirectSale_free() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    mockPayout(amount, seller);
    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(address(testErc721), address(0), 0, startTime, splitRecipients, splitRatios);
    vm.stopPrank();

    uint256 charlieBalanceBefore = charlie.balance;
    uint256 aliceBalanceBefore = alice.balance;
    // Warp to start time
    vm.warp(block.timestamp + 60);
    vm.startPrank(charlie);
    rareMinter.mintDirectSale(address(testErc721), address(0), 0, numMints);
    vm.stopPrank();

    // Check that the token was minted
    address tokenOwner = testErc721.ownerOf(1);
    if (charlie != tokenOwner) {
      emit log_named_address("Expected: tokenOwner", charlie);
      emit log_named_address("Actual: tokenOwner", tokenOwner);
      revert("incorrect tokenOwner");
    }

    // Check Payment
    uint256 charlieBalanceAfter = charlie.balance;
    uint256 actualDifferenceCharlie = charlieBalanceBefore - charlieBalanceAfter;
    uint256 expectedDifferenceCharlie = 0;
    if (actualDifferenceCharlie != expectedDifferenceCharlie) {
      emit log_named_uint("Expected: difference ", expectedDifferenceCharlie);
      emit log_named_uint("Actual: difference", actualDifferenceCharlie);
      emit log_named_uint("charlieBalanceBefore", charlieBalanceBefore);
      emit log_named_uint("charlieBalanceAfter", charlieBalanceAfter);
      revert("incorrect  payment for free mint");
    }
    uint256 aliceBalanceAfter = alice.balance;
    uint256 actualDifference = aliceBalanceAfter - aliceBalanceBefore;
    uint256 expectedDifference = 0;
    if (actualDifference != expectedDifference) {
      emit log_named_uint("Expected: difference ", expectedDifference);
      emit log_named_uint("Actual: difference", actualDifference);
      emit log_named_uint("aliceBalanceBefore", aliceBalanceBefore);
      emit log_named_uint("aliceBalanceAfter", aliceBalanceAfter);
      revert("incorrect  payment for free mint");
    }
  }

  function test_mintDirectSale_fail_startTime() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    mockPayout(amount, seller);
    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(address(testErc721), address(0), price, startTime, splitRecipients, splitRatios);
    vm.stopPrank();

    // Warp to start time
    vm.startPrank(charlie);
    vm.expectRevert();
    rareMinter.mintDirectSale{value: amount + (amount * 3) / 100}(address(testErc721), address(0), price, 3);
    vm.stopPrank();
  }

  function test_mintDirectSale_fail_not_configured() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    mockPayout(amount, seller);
    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    vm.startPrank(charlie);
    vm.expectRevert();
    rareMinter.mintDirectSale{value: amount + (amount * 3) / 100}(address(testErc721), address(0), price, 3);
    vm.stopPrank();
  }

  function test_mintDirectSale_fail_wrong_price() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 wrongPrice = 0.5 ether;
    uint256 amount = wrongPrice * numMints;
    mockPayout(amount, seller);
    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(address(testErc721), address(0), price, startTime, splitRecipients, splitRatios);
    vm.stopPrank();

    // Warp to start time
    vm.warp(startTime);

    vm.startPrank(charlie);
    vm.expectRevert();
    rareMinter.mintDirectSale{value: amount + (amount * 3) / 100}(address(testErc721), address(0), wrongPrice, 3);
    vm.stopPrank();
  }

  function test_mintDirectSale_fail_wrong_currency() public {
    address seller = alice;
    uint8 numMints = 3;
    uint256 price = 1 ether;
    uint256 amount = price * numMints;
    mockPayout(amount, seller);
    vm.prank(deployer);
    testErc721.transferOwnership(alice);

    // Prepare the mint
    address payable[] memory splitRecipients = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRecipients[0] = payable(alice);
    splitRatios[0] = 100;
    uint256 startTime = block.timestamp + 60;

    vm.startPrank(alice);
    rareMinter.prepareMintDirectSale(address(testErc721), address(0), price, startTime, splitRecipients, splitRatios);
    vm.stopPrank();

    // Warp to start time
    vm.warp(startTime);

    vm.startPrank(charlie);
    vm.expectRevert();
    rareMinter.mintDirectSale(address(testErc721), currencyAddress, price, 3);
    vm.stopPrank();
  }

  function mockPayout(uint256 _amount, address _seller) internal {
    // setup getRewardAccumulatorAddressForUser call
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getRewardAccumulatorAddressForUser.selector, _seller),
      abi.encode(address(0))
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
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, address(testErc721), 1),
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
      abi.encodeWithSelector(
        IMarketplaceSettings.getERC721ContractPrimarySaleFeePercentage.selector,
        address(testErc721)
      ),
      abi.encode(15)
    );
  }
}
