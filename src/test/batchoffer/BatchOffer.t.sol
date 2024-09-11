// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Merkle} from "murky/Merkle.sol";

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {IERC721Mint} from "../../collection/IERC721Mint.sol";
import "openzeppelin-contracts/access/Ownable.sol";

import {IBatchOffer} from "../../batchoffer/IBatchOffer.sol";
import {BatchOfferCreator} from "../../batchoffer/BatchOffer.sol";
import {IMarketplaceSettings} from "rareprotocol/aux/marketplace/IMarketplaceSettings.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IRareRoyaltyRegistry} from "rareprotocol/aux/registry/interfaces/IRareRoyaltyRegistry.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";
import {ISpaceOperatorRegistry} from "rareprotocol/aux/registry/interfaces/ISpaceOperatorRegistry.sol";
import {IRareStakingRegistry} from "../../staking/registry/IRareStakingRegistry.sol";
import {IApprovedTokenRegistry} from "rareprotocol/aux/registry/interfaces/IApprovedTokenRegistry.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";

contract TestERC721 is ERC721, IERC721Mint, Ownable {
  uint256 private tokenCount;

  constructor() ERC721("TestERC721", "TEST") {}

  function mintTo(address _receiver) external returns (uint256) {
    tokenCount++;
    _mint(_receiver, tokenCount);
    return tokenCount;
  }
}

contract TestBatchOffer is Test {
  BatchOfferCreator offerCreator;
  TestERC721 testToken;
  uint256 testTokenId;

  address deployer = address(0xabadabab);
  address stakingSettings = address(0xabadaba0);
  address marketplaceSettings = address(0xabadaba1);
  address royaltyRegistry = address(0xabadaba2);
  address royaltyEngine = address(0xabadaba3);
  address spaceOperatorRegistry = address(0xabadaba6);
  address approvedTokenRegistry = address(0xabadaba7);
  address stakingRegistry = address(0xabadaba9);
  address networkBeneficiary = address(0xabadabaa);

  uint8 marketplaceFeePercentage = 3;

  address ryan = address(0xcafe);
  address notryan = address(0xcafd);

  function setUp() public {
    vm.startPrank(deployer);

    testToken = new TestERC721();
    testTokenId = testToken.mintTo(notryan);

    vm.deal(deployer, 5 ether);
    vm.deal(ryan, 5 ether);
    vm.deal(notryan, 5 ether);

    offerCreator = new BatchOfferCreator();
    offerCreator.initialize(
      networkBeneficiary,
      marketplaceSettings,
      spaceOperatorRegistry,
      royaltyEngine,
      address(new Payments()),
      approvedTokenRegistry,
      stakingSettings,
      stakingRegistry
    );

    vm.etch(marketplaceSettings, address(offerCreator).code);
    vm.etch(stakingSettings, address(offerCreator).code);
    vm.etch(stakingRegistry, address(offerCreator).code);
    vm.etch(royaltyRegistry, address(offerCreator).code);
    vm.etch(royaltyEngine, address(offerCreator).code);
    vm.etch(spaceOperatorRegistry, address(offerCreator).code);
    vm.etch(approvedTokenRegistry, address(offerCreator).code);

    vm.stopPrank();
  }

  function test_sendAndAcceptBatchOffer() public {
    vm.prank(deployer);

    uint256 amount = 100;

    mockPayout(100, notryan);

    testToken.transferOwnership(notryan);

    address payable[] memory _splitRecipients = new address payable[](1);
    uint8[] memory _splitRatios = new uint8[](1);
    _splitRecipients[0] = payable(notryan);
    _splitRatios[0] = 100;

    Merkle m = new Merkle();
    bytes32[] memory data = new bytes32[](2);
    data[0] = keccak256(abi.encodePacked(address(testToken), testTokenId));
    data[1] = keccak256(abi.encodePacked(address(testToken), uint256(2)));
    bytes32 _rootHash = m.getRoot(data);
    bytes32[] memory _proof = m.getProof(data, 0);

    vm.startPrank(ryan);
    offerCreator.createBatchOffer{value: amount + (amount * 3) / 100}(
      _rootHash,
      amount,
      address(0),
      block.timestamp + 200
    );

    vm.startPrank(notryan);

    testToken.setApprovalForAll(address(offerCreator), true);

    offerCreator.acceptBatchOffer(
      _proof,
      _rootHash,
      address(testToken),
      testTokenId,
      _splitRecipients,
      _splitRatios
    );

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
      abi.encodeWithSelector(IMarketplaceSettings.hasERC721TokenSold.selector, address(testToken), 1),
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
        address(testToken)
      ),
      abi.encode(15)
    );
  }
}
