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
import {Payments} from "rareprotocol/aux/payments/Payments.sol";

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

  address ryan = address(0xcafe);
  address notryan = address(0xcafd);

  function setUp() public {
    vm.startPrank(deployer);

    testToken = new TestERC721();
    testTokenId = testToken.mintTo(notryan);

    deal(deployer, 100 ether);
    deal(ryan, 100 ether);
    deal(notryan, 100 ether);

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

    Merkle m = new Merkle();
    bytes32[] memory data = new bytes32[](2);
    data[0] = keccak256(abi.encodePacked(address(testToken), testTokenId));
    data[1] = keccak256(abi.encodePacked(address(testToken), uint256(2)));
    bytes32 root = m.getRoot(data);

    vm.startPrank(ryan);
    offerCreator.createBatchOffer(root, 1, address(0), block.timestamp + 200);
    vm.stopPrank();

    IBatchOffer.BatchOffer memory storedOffer = offerCreator.getBatchOffer(root);
    if (storedOffer.amount == 0) {
      revert("offer create failed");
    }
  }

  function test_acceptBatchOffer() public {
    vm.prank(deployer);

    testToken.transferOwnership(notryan);

    uint256 _amount = 1;
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
    offerCreator.createBatchOffer(_rootHash, 1, address(0), block.timestamp + 200);

    vm.startPrank(notryan);
    offerCreator.acceptBatchOffer(
      _proof,
      _rootHash,
      address(testToken),
      testTokenId,
      address(0),
      _amount,
      _splitRecipients,
      _splitRatios
    );

    vm.stopPrank();
  }
}
