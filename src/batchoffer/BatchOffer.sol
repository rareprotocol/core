// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ensdomains/governance/MerkleProof.sol";

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
contract BatchOfferCreator is
  Initializable,
  IBatchOffer,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  using MarketUtils for MarketConfig.Config;
  using MarketConfig for MarketConfig.Config;

  /*//////////////////////////////////////////////////////////////////////////
                            Storage
  //////////////////////////////////////////////////////////////////////////*/
  MarketConfig.Config private marketConfig;

  mapping(address => mapping(bytes32 => BatchOffer)) private _creatorToRootToOffer;

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
    require(_networkBeneficiary != address(0), "BatchOfferCreator::networkBeneficiary address must be set");
    require(_marketplaceSettings != address(0), "BatchOfferCreator::marketplaceSettings address must be set");
    require(_spaceOperatorRegistry != address(0), "BatchOfferCreator::spaceOperatorRegistry address must be set");
    require(_royaltyEngine != address(0), "BatchOfferCreator::royaltyEngine address must be set");
    require(_payments != address(0), "BatchOfferCreator::payments address must be set");
    require(_approvedTokenRegistry != address(0), "BatchOfferCreator::approvedTokenRegistry address must be set");
    require(_stakingSettings != address(0), "BatchOfferCreator::stakingSettings address must be set");
    require(_stakingRegistry != address(0), "BatchOfferCreator::stakingRegistry address must be set");

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
  function createBatchOffer(
    bytes32 _rootHash,
    uint256 _amount,
    address _currency,
    uint256 _expiry
  ) external payable nonReentrant {
    require(_creatorToRootToOffer[msg.sender][_rootHash].creator == address(0), "createBatchOffer::offer exists");
    marketConfig.checkIfCurrencyIsApproved(_currency);
    require(_expiry > block.timestamp, "createBatchOffer::expiry must be in the future");
    require(_amount > 0, "offer::Amount cannot be 0");
    require(_rootHash != bytes32(0), "createBatchOffer::rootHash cannot be 0");

    _creatorToRootToOffer[msg.sender][_rootHash] = BatchOffer(
      msg.sender,
      _rootHash,
      _amount,
      _currency,
      _expiry,
      marketConfig.marketplaceSettings.getMarketplaceFeePercentage()
    );

    uint256 requiredAmount = _amount + marketConfig.marketplaceSettings.calculateMarketplaceFee(_amount);
    MarketUtils.checkAmountAndTransfer(_currency, requiredAmount);

    emit BatchOfferCreated(msg.sender, _rootHash, _amount, _currency, _expiry);
  }

  function revokeBatchOffer(bytes32 _rootHash) external nonReentrant {
    // Load Offer
    BatchOffer memory offer = _creatorToRootToOffer[msg.sender][_rootHash];

    require(offer.creator == msg.sender, "createBatchOffer::must be owner");

    // Cleanup memory
    // IMPORTANT: Must be done before external refund call
    delete _creatorToRootToOffer[msg.sender][_rootHash];

    // Refund Escrow
    marketConfig.refund(offer.currency, offer.amount, offer.feePercentage, offer.creator);

    emit BatchOfferRevoked(msg.sender, _rootHash, offer.currency, offer.amount);
  }

  function acceptBatchOffer(
    address _creator,
    bytes32[] memory _proof,
    bytes32 _rootHash,
    address _contractAddress,
    uint256 _tokenId,
    address payable[] calldata _splitRecipients,
    uint8[] calldata _splitRatios
  ) external payable nonReentrant {
    IERC721 erc721 = IERC721(_contractAddress);
    address tokenOwner = erc721.ownerOf(_tokenId);

    require(msg.sender == tokenOwner, "acceptBatchOffer::Must be tokenOwner");

    BatchOffer memory offer = _creatorToRootToOffer[_creator][_rootHash];
    address currency = offer.currency;
    marketConfig.checkIfCurrencyIsApproved(currency);
    require(offer.creator != address(0), "acceptBatchOffer::offer does not exist");
    require(offer.expiry > block.timestamp, "acceptBatchOffer::offer expired");
    bytes32 leaf = keccak256(abi.encodePacked(_contractAddress, _tokenId));
    (bool success, ) = MerkleProof.verify(_proof, offer.rootHash, leaf);
    require(success, "Invalid _proof");
    MarketUtils.checkSplits(_splitRecipients, _splitRatios);

    // Cleanup memory
    // IMPORTANT: Must be done before external payout
    delete _creatorToRootToOffer[_creator][_rootHash];

    // Perform payout
    // TODO: test case to make sure mark as sold is performed after payout
    if (offer.amount != 0) {
      marketConfig.payout(
        _contractAddress,
        _tokenId,
        currency,
        offer.amount,
        msg.sender,
        _splitRecipients,
        _splitRatios
      );
    }

    // Transfer ERC721 token from the seller to the buyer
    IERC721 erc721Token = IERC721(_contractAddress);
    erc721Token.safeTransferFrom(msg.sender, offer.creator, _tokenId);

    // If payout and transfer succeed, check token and mark as sold
    require(offer.creator == erc721Token.ownerOf(_tokenId), "acceptBatchOffer::ERC721 transfer failed");
    try marketConfig.marketplaceSettings.markERC721Token(_contractAddress, _tokenId, true) {} catch {}

    emit BatchOfferAccepted(msg.sender, offer.creator, _contractAddress, _tokenId, _rootHash, currency, offer.amount);
  }

  //////////////////////////////////////////////////////////////////////////
  //                      Internal UUPS Functions
  //////////////////////////////////////////////////////////////////////////
  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}

  /*//////////////////////////////////////////////////////////////////////////
                        External Read Functions
    //////////////////////////////////////////////////////////////////////////*/

  // Getter function for _rootToOffer mapping
  function getBatchOffer(address creator, bytes32 rootHash) external view returns (BatchOffer memory) {
    return _creatorToRootToOffer[creator][rootHash];
  }
}
