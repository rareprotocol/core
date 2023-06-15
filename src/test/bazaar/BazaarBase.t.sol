// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IMarketplaceSettings} from "rareprotocol/aux/marketplace/IMarketplaceSettings.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IRoyaltyRegistry} from "rareprotocol/aux/registry/interfaces/IRoyaltyRegistry.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";
import {ISpaceOperatorRegistry} from "rareprotocol/aux/registry/interfaces/ISpaceOperatorRegistry.sol";
import {IApprovedTokenRegistry} from "rareprotocol/aux/registry/interfaces/IApprovedTokenRegistry.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../../bazaar/SuperRareBazaarBase.sol";

import {MarketUtils} from "../../utils/MarketUtils.sol";
import {MarketConfig} from "../../utils/structs/MarketConfig.sol";
import {IRareStakingRegistry} from "../../staking/registry/IRareStakingRegistry.sol";

contract TestContract is SuperRareBazaarBase {
  constructor(
    address _marketplaceSettings,
    address _royaltyEngine,
    address _spaceOperatorRegistry,
    address _approvedTokenRegistry,
    address _payments,
    address _stakingRegistry,
    address _networkBeneficiary
  ) {
    marketplaceSettings = IMarketplaceSettings(_marketplaceSettings);
    royaltyEngine = IRoyaltyEngineV1(_royaltyEngine);
    spaceOperatorRegistry = ISpaceOperatorRegistry(_spaceOperatorRegistry);
    approvedTokenRegistry = IApprovedTokenRegistry(_approvedTokenRegistry);
    payments = IPayments(_payments);
    stakingRegistry = _stakingRegistry;
    networkBeneficiary = _networkBeneficiary;

    minimumBidIncreasePercentage = 10;
    maxAuctionLength = 7 days;
    auctionLengthExtension = 15 minutes;
    offerCancelationDelay = 5 minutes;
  }

  function payout(
    address _originContract,
    uint256 _tokenId,
    address _currencyAddress,
    uint256 _amount,
    address _seller,
    address payable[] memory _splitAddrs,
    uint8[] memory _splitRatios
  ) public payable {
    _payout(_originContract, _tokenId, _currencyAddress, _amount, _seller, _splitAddrs, _splitRatios);
  }
}

contract TestRare is ERC20 {
  constructor() ERC20("Rare", "RARE") {
    _mint(msg.sender, 1_000_000_000 ether);
  }

  function burn(uint256 amount) public {
    _burn(msg.sender, amount);
  } 
}

contract RareBazaarBaseTest is Test {
  TestContract tc;
  Payments payments;
  TestRare public rare;
  uint256 constant initialRare = 1000 * 1e18;

  address deployer = address(0xabadabab);
  address alice = address(0xbeef);
  address bob = address(0xcafe);
  address charlie = address(0xdead);
  address marketplaceSettings = address(0xabadaba1);
  address royaltyRegistry = address(0xabadaba2);
  address royaltyEngine = address(0xabadaba3);
  address spaceOperatorRegistry = address(0xabadaba6);
  address approvedTokenRegistry = address(0xabadaba7);
  address stakingRegistry = address(0xabadaba9);
  address networkBeneficiary = address(0xabadabaa);
  address rewardPool = address(0xcccc);

  function contractDeploy() internal {
    vm.startPrank(deployer);

    // Deploy TestRare
    rare = new TestRare();

    // Deploy Payments
    payments = new Payments();

    tc = new TestContract(
      marketplaceSettings,
      royaltyEngine,
      spaceOperatorRegistry,
      approvedTokenRegistry,
      address(payments),
      stakingRegistry,
      networkBeneficiary
    );

    // etch code into these so we can stub out methods. Need some
    vm.etch(marketplaceSettings, address(rare).code);
    vm.etch(stakingRegistry, address(rare).code);
    vm.etch(royaltyRegistry, address(rare).code);
    vm.etch(royaltyEngine, address(rare).code);
    vm.etch(spaceOperatorRegistry, address(rare).code);
    vm.etch(approvedTokenRegistry, address(rare).code);

    vm.stopPrank();
  }

  function setUp() public {
    deal(deployer, 100 ether);
    deal(alice, 100 ether);
    deal(bob, 100 ether);
    deal(charlie, 100 ether);
    contractDeploy();
    vm.startPrank(deployer);
    rare.transfer(alice, initialRare);
    rare.transfer(bob, initialRare);
    vm.stopPrank();
  }

  function test_payout_primary() public {
    address originContract = address(0xaaaa);
    uint256 tokenId = 1;
    address currencyAddress = address(0);
    uint256 amount = 1 ether;
    address payable[] memory splitAddrs = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    splitAddrs[0] = payable(charlie);

    // setup getStakingInfoForUser call -- 3%
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getStakingInfoForUser.selector, charlie),
      abi.encode(IRareStakingRegistry.Info("", "", address(0), address(0)))
    );

    // setup calculateMarketplacePayoutFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, amount),
      abi.encode((amount * 3) / 100)
    );

    // setup calculateStakingFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, amount),
      abi.encode(0)
    );

    // setup calculateMarketplaceFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, amount),
      abi.encode((amount * 3) / 100)
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
      abi.encodeWithSelector(ISpaceOperatorRegistry.isApprovedSpaceOperator.selector, charlie),
      abi.encode(false)
    );

    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getERC721ContractPrimarySaleFeePercentage.selector, originContract),
      abi.encode(15)
    );
    uint256 balanceBefore = charlie.balance;
    vm.prank(deployer);
    tc.payout{value: amount + ((amount * 3) / 100)}(
      originContract,
      tokenId,
      currencyAddress,
      amount,
      charlie,
      splitAddrs,
      splitRatios
    );
    uint256 balanceAfter = charlie.balance;
    uint256 expectedBalance = balanceBefore + ((amount * 85) / 100);
    if (balanceAfter != expectedBalance) {
      emit log_named_uint("Expected: balanceAfter", expectedBalance);
      emit log_named_uint("Actual: balanceAfter", balanceAfter);
      revert("incorrect balance after on payout");
    }
  }

  function test_payout_primary_spaces() public {
    address originContract = address(0xaaaa);
    uint256 tokenId = 1;
    address currencyAddress = address(0);
    uint256 amount = 1 ether;
    address payable[] memory splitAddrs = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    splitAddrs[0] = payable(charlie);

    // setup getStakingInfoForUser call -- 3%
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getStakingInfoForUser.selector, charlie),
      abi.encode(IRareStakingRegistry.Info("", "", address(0), address(0)))
    );

    // setup calculateMarketplacePayoutFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, amount),
      abi.encode((amount * 3) / 100)
    );

    // setup calculateStakingFee call -- 0%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, amount),
      abi.encode(0)
    );

    // setup calculateMarketplaceFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, amount),
      abi.encode((amount * 3) / 100)
    );

    // setup hasERC721TokenSold -- false
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, originContract, 1),
      abi.encode(false)
    );
    // setup isApprovedSpaceOperator -- true
    vm.mockCall(
      spaceOperatorRegistry,
      abi.encodeWithSelector(ISpaceOperatorRegistry.isApprovedSpaceOperator.selector, charlie),
      abi.encode(true)
    );

    // setup getPlatformCommission -- 5%
    vm.mockCall(
      spaceOperatorRegistry,
      abi.encodeWithSelector(ISpaceOperatorRegistry.getPlatformCommission.selector, charlie),
      abi.encode(5)
    );
    uint256 balanceBefore = charlie.balance;
    vm.prank(deployer);
    tc.payout{value: amount + ((amount * 3) / 100)}(
      originContract,
      tokenId,
      currencyAddress,
      amount,
      charlie,
      splitAddrs,
      splitRatios
    );
    uint256 balanceAfter = charlie.balance;
    uint256 expectedBalance = balanceBefore + ((amount * 95) / 100);
    if (balanceAfter != expectedBalance) {
      emit log_named_uint("Expected: balanceAfter", expectedBalance);
      emit log_named_uint("Actual: balanceAfter", balanceAfter);
      revert("incorrect balance after on payout");
    }
  }

  function test_payout_secondary() public {
    address originContract = address(0xaaaa);
    uint256 tokenId = 1;
    address currencyAddress = address(0);
    uint256 amount = 1 ether;
    address payable[] memory splitAddrs = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    splitAddrs[0] = payable(charlie);
    address payable[] memory royaltyReceiverAddrs = new address payable[](1);
    uint256[] memory royaltyAmounts = new uint256[](1);
    royaltyReceiverAddrs[0] = payable(alice);
    royaltyAmounts[0] = (amount * 10) / 100;

    // setup calculateMarketplaceFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, amount),
      abi.encode((amount * 3) / 100)
    );

    // setup getStakingInfoForUser call -- 3%
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getStakingInfoForUser.selector, charlie),
      abi.encode(IRareStakingRegistry.Info("", "", address(0), address(0)))
    );

    // setup calculateMarketplacePayoutFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, amount),
      abi.encode((amount * 3) / 100)
    );

    // setup calculateStakingFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, amount),
      abi.encode(0)
    );

    // setup has hasERC721TokenSold -- false
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, originContract, 1),
      abi.encode(true)
    );

    // setup has getRoyalty -- 10%
    vm.mockCall(
      royaltyEngine,
      abi.encodeWithSelector(IRoyaltyEngineV1.getRoyalty.selector, originContract, 1, amount),
      abi.encode(royaltyReceiverAddrs, royaltyAmounts)
    );

    uint256 balanceBefore = charlie.balance;
    uint256 aliceBalanceBefore = alice.balance;
    vm.prank(deployer);
    tc.payout{value: amount + ((amount * 3) / 100)}(
      originContract,
      tokenId,
      currencyAddress,
      amount,
      charlie,
      splitAddrs,
      splitRatios
    );
    uint256 balanceAfter = charlie.balance;
    uint256 expectedBalance = balanceBefore + ((amount * 90) / 100);
    uint256 aliceBalanceAfter = alice.balance;
    uint256 aliceExpectedBalance = aliceBalanceBefore + ((amount * 10) / 100);
    if (balanceAfter != expectedBalance) {
      emit log_named_uint("Expected: balanceAfter", expectedBalance);
      emit log_named_uint("Actual: balanceAfter", balanceAfter);
      revert("incorrect balance after on payout");
    }
    if (balanceAfter != expectedBalance) {
      emit log_named_uint("Expected: aliceExpectedBalance", aliceExpectedBalance);
      emit log_named_uint("Actual: aliceBalanceAfter", aliceBalanceAfter);
      revert("incorrect balance after on payout");
    }
  }

  function test_payout_staking_pool() public {
    address originContract = address(0xaaaa);
    uint256 tokenId = 1;
    address currencyAddress = address(0);
    uint256 amount = 1 ether;
    address payable[] memory splitAddrs = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    splitAddrs[0] = payable(charlie);

    // setup getStakingInfoForUser call -- 3%
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getStakingInfoForUser.selector, charlie),
      abi.encode(IRareStakingRegistry.Info("", "", address(0), rewardPool))
    );

    // setup calculateMarketplacePayoutFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, amount),
      abi.encode((amount * 2) / 100)
    );

    // setup calculateStakingFee call -- 1%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, amount),
      abi.encode(amount / 100)
    );

    // setup calculateMarketplaceFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, amount),
      abi.encode((amount * 3) / 100)
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
      abi.encodeWithSelector(ISpaceOperatorRegistry.isApprovedSpaceOperator.selector, charlie),
      abi.encode(false)
    );

    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getERC721ContractPrimarySaleFeePercentage.selector, originContract),
      abi.encode(15)
    );
    uint256 balanceBefore = rewardPool.balance;
    vm.prank(deployer);
    tc.payout{value: amount + ((amount * 3) / 100)}(
      originContract,
      tokenId,
      currencyAddress,
      amount,
      charlie,
      splitAddrs,
      splitRatios
    );
    uint256 balanceAfter = rewardPool.balance;
    uint256 expectedBalance = balanceBefore + (amount / 100);
    if (balanceAfter != expectedBalance) {
      emit log_named_uint("Expected: balanceAfter", expectedBalance);
      emit log_named_uint("Actual: balanceAfter", balanceAfter);
      revert("incorrect balance after on payout");
    }
  }

  function test_payout_no_staking_pool() public {
    address originContract = address(0xaaaa);
    uint256 tokenId = 1;
    address currencyAddress = address(0);
    uint256 amount = 1 ether;
    address payable[] memory splitAddrs = new address payable[](1);
    uint8[] memory splitRatios = new uint8[](1);
    splitRatios[0] = 100;
    splitAddrs[0] = payable(charlie);

    // setup getStakingInfoForUser call -- 3%
    vm.mockCall(
      stakingRegistry,
      abi.encodeWithSelector(IRareStakingRegistry.getStakingInfoForUser.selector, charlie),
      abi.encode(IRareStakingRegistry.Info("", "", address(0), address(0)))
    );

    // setup calculateMarketplacePayoutFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateMarketplacePayoutFee.selector, amount),
      abi.encode((amount * 2) / 100)
    );

    // setup calculateStakingFee call -- 1%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IStakingSettings.calculateStakingFee.selector, amount),
      abi.encode(amount / 100)
    );

    // setup calculateMarketplaceFee call -- 3%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.calculateMarketplaceFee.selector, amount),
      abi.encode((amount * 3) / 100)
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
      abi.encodeWithSelector(ISpaceOperatorRegistry.isApprovedSpaceOperator.selector, charlie),
      abi.encode(false)
    );

    // setup has getERC721ContractPrimarySaleFeePercentage -- 15%
    vm.mockCall(
      marketplaceSettings,
      abi.encodeWithSelector(IMarketplaceSettings.getERC721ContractPrimarySaleFeePercentage.selector, originContract),
      abi.encode(15)
    );
    vm.prank(deployer);
    tc.payout{value: amount + ((amount * 3) / 100)}(
      originContract,
      tokenId,
      currencyAddress,
      amount,
      charlie,
      splitAddrs,
      splitRatios
    );
    uint256 balanceAfter = rewardPool.balance;
    uint256 expectedBalance = balanceAfter;
    if (balanceAfter != expectedBalance) {
      emit log_named_uint("Expected: balanceAfter", expectedBalance);
      emit log_named_uint("Actual: balanceAfter", balanceAfter);
      revert("incorrect balance after on payout");
    }
  }
}
