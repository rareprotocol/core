// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ensdomains/governance/MerkleProof.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {IBatchOffer} from "./IBatchOffer.sol";
import {MarketConfig} from "../utils/structs/MarketConfig.sol";
import {MarketUtils} from "../utils/MarketUtils.sol";

/// @author SuperRare Labs Inc.
/// @title BatchOfferCreator
/// @notice Creates batch offers
contract BatchOfferCreator is Initializable, IBatchOffer, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  using MarketUtils for MarketConfig.Config;
  using MarketConfig for MarketConfig.Config;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  /*//////////////////////////////////////////////////////////////////////////
                            Storage
    //////////////////////////////////////////////////////////////////////////*/
  MarketConfig.Config private marketConfig;

  mapping(bytes32 => BatchOffer) private _rootToOffer;

  EnumerableSet.Bytes32Set private _roots;

  //////////////////////////////////////////////////////////////////////////
  //                      Initializer
  //////////////////////////////////////////////////////////////////////////
  function initialize(
    address _networkBeneficiary,
    address _marketplaceSettings,
    address _spaceOperatorRegistry,
    address _royaltyEngine,
    address _payments,
    address _approvedTokenRegistry,
    address _stakingSettings,
    address _stakingRegistry
  ) external initializer {
    marketConfig = MarketConfig.generateMarketConfig(
      _networkBeneficiary,
      _marketplaceSettings,
      _spaceOperatorRegistry,
      _royaltyEngine,
      _payments,
      _approvedTokenRegistry,
      _stakingSettings,
      _stakingRegistry
    );
    __Ownable_init();
  }

  /*//////////////////////////////////////////////////////////////////////////
                        External Write Functions
    //////////////////////////////////////////////////////////////////////////*/
  function createBatchOffer(bytes32 _rootHash, uint256 _amount, address _currency, uint256 _expiry) external {
    require(_rootToOffer[_rootHash].creator == address(0), "createBatchOffer::offer exists");
    marketConfig.checkIfCurrencyIsApproved(_currency);
    require(_expiry > block.timestamp, "createBatchOffer::expiry must be in the future");

    _rootToOffer[_rootHash] = BatchOffer(msg.sender, _rootHash, _amount, _currency, _expiry);
    _roots.add(_rootHash);
    emit BatchOfferCreated(msg.sender, _rootHash, _amount, _currency, _expiry);
  }

  function revokeBatchOffer(bytes32 _rootHash) external {
    require(_rootToOffer[_rootHash].creator == msg.sender, "createBatchOffer::must be owner");

    // Cleanup memory
    _roots.remove(_rootHash);
    delete _rootToOffer[_rootHash];
  }

  function acceptBatchOffer(
    bytes32[] memory _proof,
    bytes32 _rootHash,
    address _contractAddress,
    uint256 _tokenId,
    address _currency,
    uint256 _amount,
    address payable[] calldata _splitRecipients,
    uint8[] calldata _splitRatios
  ) external payable nonReentrant {
    IERC721 erc721 = IERC721(_contractAddress);
    address tokenOwner = erc721.ownerOf(_tokenId);

    require(msg.sender == tokenOwner, "acceptBatchOffer::Must be tokenOwner");
    marketConfig.checkIfCurrencyIsApproved(_currency);

    BatchOffer memory offer = _rootToOffer[_rootHash];
    require(offer.creator != address(0), "acceptBatchOffer::offer does not exist");
    require(offer.expiry > block.timestamp, "acceptBatchOffer::offer expired");
    require(offer.rootHash == _rootHash, "acceptBatchOffer::root mismatch");
    bytes32 leaf = keccak256(abi.encodePacked(_contractAddress, _tokenId));
    (bool success, ) = MerkleProof.verify(_proof, offer.rootHash, leaf);
    require(success, "Invalid _proof");

    // Cleanup memory
    _roots.remove(_rootHash);
    delete _rootToOffer[_rootHash];

    // Perform payout
    // TODO: test case to make sure mark as sold is performed after payout
    if (_amount != 0) {
      marketConfig.payout(_contractAddress, _tokenId, _currency, _amount, msg.sender, _splitRecipients, _splitRatios);
    }

    // Transfer ERC721 token from the seller to the buyer
    IERC721 erc721Token = IERC721(_contractAddress);
    erc721Token.safeTransferFrom(msg.sender, offer.creator, _tokenId);

    // If payout and transfer succeed, mark as sold
    try marketConfig.marketplaceSettings.markERC721Token(_contractAddress, _tokenId, true) {} catch {}

    emit BatchOfferAccepted(msg.sender, offer.creator, _contractAddress, _tokenId, _rootHash, _currency, _amount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                        External Read Functions
    //////////////////////////////////////////////////////////////////////////*/

  // Getter function for _rootToOffer mapping
  function getBatchOffer(bytes32 rootHash) external view returns (BatchOffer memory) {
    return _rootToOffer[rootHash];
  }

  // Getter function for _roots EnumerableSet
  function getRoots() external view returns (bytes32[] memory) {
    uint256 size = _roots.length();
    bytes32[] memory result = new bytes32[](size);
    for (uint256 i = 0; i < size; i++) {
      result[i] = _roots.at(i);
    }
    return result;
  }
}
