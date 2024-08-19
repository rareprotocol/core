// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {BatchOfferCreator} from "../../batchoffer/BatchOffer.sol";

contract TestCurrency is ERC20 {
  constructor() ERC20("Currency", "CUR") {
    _mint(msg.sender, 1_000_000_000 ether);
  }
}

// contract TestERC721 is ERC721, IERC721Mint, Ownable {
//   uint256 private tokenCount;

//   constructor() ERC721("TestERC721", "TEST") {}

//   function mintTo(address _receiver) external returns (uint256) {
//     tokenCount++;
//     _mint(_receiver, tokenCount);
//     return tokenCount;
//   }
// }

contract TestBatchOffer is Test {
  BatchOfferCreator offerCretor;
  TestCurrency currency;
  TestERC721 testErc721;

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

    // Deploy Test Assets
    currency = new TestCurrency();
    // testErc721 = new TestERC721();
    currencyAddress = address(currency);

    offerCreator = new BatchOfferCreator;
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

    vm.etch(marketplaceSettings, address(rareMinter).code);
    vm.etch(stakingSettings, address(rareMinter).code);
    vm.etch(stakingRegistry, address(rareMinter).code);
    vm.etch(royaltyRegistry, address(rareMinter).code);
    vm.etch(royaltyEngine, address(rareMinter).code);
    vm.etch(spaceOperatorRegistry, address(rareMinter).code);
    vm.etch(approvedTokenRegistry, address(rareMinter).code);

    vm.stopPrank();
  }

  function test_createBatchOffer() public {
    vm.prank(deployer);
    offerCreator.createBatchOffer(
      "e2f05447de94f4cd02902ffc2554d41b1cd8422528571125749db2a45d853edb",
      1,
      currency,
      vm.block.timestamp + 200
    );
    vm.stopPrank();

    if (offerCreator.getBatchOffer("e2f05447de94f4cd02902ffc2554d41b1cd8422528571125749db2a45d853edb") == bytes32(0)) {
      revert("offer create failed");
    }
  }
}
