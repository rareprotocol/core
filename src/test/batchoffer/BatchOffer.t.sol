// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {IBatchOffer} from "../../batchoffer/IBatchOffer.sol";
import {BatchOfferCreator} from "../../batchoffer/BatchOffer.sol";
import {Payments} from "rareprotocol/aux/payments/Payments.sol";

contract TestCurrency is ERC20 {
  constructor() ERC20("Currency", "CUR") {
    _mint(msg.sender, 1_000_000_000 ether);
  }
}

contract TestBatchOffer is Test {
  BatchOfferCreator offerCreator;
  TestCurrency currency;

  address deployer = address(0xabadabab);
  address stakingSettings = address(0xabadaba0);
  address marketplaceSettings = address(0xabadaba1);
  address royaltyRegistry = address(0xabadaba2);
  address royaltyEngine = address(0xabadaba3);
  address spaceOperatorRegistry = address(0xabadaba6);
  address approvedTokenRegistry = address(0xabadaba7);
  address stakingRegistry = address(0xabadaba9);
  address networkBeneficiary = address(0xabadabaa);

  address zeroAddress = address(0);
  bytes32[] emptyProof = new bytes32[](0);
  uint256 tokenId = 123;
  uint8 marketplaceFeePercentage = 3;

  address currencyAddress;

  function setUp() public {
    vm.startPrank(deployer);

    currency = new TestCurrency();
    currencyAddress = address(currency);

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

  function test_createBatchOffer() public {
    vm.prank(deployer);

    bytes32 root = 0xe2f05447de94f4cd02902ffc2554d41b1cd8422528571125749db2a45d853edb;

    offerCreator.createBatchOffer(root, 1, currencyAddress, block.timestamp + 200);
    vm.stopPrank();

    IBatchOffer.BatchOffer memory storedOffer = offerCreator.getBatchOffer(
      bytes32(0xe2f05447de94f4cd02902ffc2554d41b1cd8422528571125749db2a45d853edb)
    );
    if (storedOffer.amount == 0) {
      revert("offer create failed");
    }
  }

  function test_acceptBatchOffer() public {
    vm.prank(deployer);

    bytes32[] memory _proof = new bytes32[](1);
    _proof[0] = 0x38576e7ee26ee6f4d2d299090ff29296be72bdffd2b2c6666fb55158cea93788;
    bytes32 _rootHash = 0xe2f05447de94f4cd02902ffc2554d41b1cd8422528571125749db2a45d853edb;
    address _contractAddress = address(0x123);
    uint256 _tokenId = 123;
    uint256 _amount = 1;
    address payable[] memory _splitRecipients = new address payable[](1);
    uint8[] memory _splitRatios = new uint8[](1);
    _splitRecipients[0] = payable(msg.sender);
    _splitRatios[0] = 100;

    currency.approve(address(offerCreator), _amount + (_amount * 3) / 100);

    offerCreator.acceptBatchOffer(
      _proof,
      _rootHash,
      _contractAddress,
      _tokenId,
      currencyAddress,
      _amount,
      _splitRecipients,
      _splitRatios
    );

    vm.stopPrank();
  }
}
