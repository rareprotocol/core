// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IRareCollectionMarket} from "./IRareCollectionMarket.sol";
import {MarketConfig} from "../utils/structs/MarketConfig.sol";
import {MarketUtils} from "../utils/MarketUtils.sol";

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract RareCollectionMarket is
  IRareCollectionMarket,
  Initializable,
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  UUPSUpgradeable
{
  using MarketUtils for MarketConfig.Config;
  using MarketConfig for MarketConfig.Config;

  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/

  MarketConfig.Config private marketConfig;

  /// @dev Mapping from UserAddr => CollectionAddr => CollectionOffer Struct
  mapping(address => mapping(address => IRareCollectionMarket.CollectionOffer)) private collectionOffers;

  /// @dev Mapping from UserAddr => CollectionAddr => CollectionSalePrice Struct
  mapping(address => mapping(address => IRareCollectionMarket.CollectionSalePrice)) private collectionSalePrices;

  /// @dev Flag to show if the contract is paused or not
  bool private paused;

  /*//////////////////////////////////////////////////////////////////////////
                                Modifiers
  //////////////////////////////////////////////////////////////////////////*/
  modifier notPaused() {
    if (paused) revert IRareCollectionMarket.ContractPaused();
    _;
  }

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/

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
                          Internal UUPS Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}

  /*//////////////////////////////////////////////////////////////////////////
                          Admin Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  function setNetworkBeneficiary(address _networkBeneficiary) external onlyOwner {
    marketConfig.updateNetworkBeneficiary(_networkBeneficiary);
  }

  function setMarketplaceSettings(address _marketplaceSettings) external onlyOwner {
    marketConfig.updateMarketplaceSettings(_marketplaceSettings);
  }

  function setSpaceOperatorRegistry(address _spaceOperatorRegistry) external onlyOwner {
    marketConfig.updateSpaceOperatorRegistry(_spaceOperatorRegistry);
  }

  function setRoyaltyEngine(address _royaltyEngine) external onlyOwner {
    marketConfig.updateRoyaltyEngine(_royaltyEngine);
  }

  function setPayments(address _payments) external onlyOwner {
    marketConfig.updatePayments(_payments);
  }

  function setApprovedTokenRegistry(address _approvedTokenRegistry) external onlyOwner {
    marketConfig.updateApprovedTokenRegistry(_approvedTokenRegistry);
  }

  function setContractPaused(bool _isPaused) external onlyOwner {
    paused = _isPaused;
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRareCollectionMarket
  function makeCollectionOffer(
    address _originContract,
    address _currencyAddress,
    uint256 _amount
  ) external payable override nonReentrant notPaused {
    marketConfig.checkIfCurrencyIsApproved(_currencyAddress);

    if (_amount == 0) revert IRareCollectionMarket.AmountCantBeZero();

    uint256 requiredAmount = _amount + marketConfig.marketplaceSettings.calculateMarketplaceFee(_amount);

    IRareCollectionMarket.CollectionOffer memory offer = collectionOffers[msg.sender][_originContract];

    // Existing Offer
    if (offer.amount != 0) {
      // if the fees and currencies match, use the offer's escrowed amount for the new offer
      if (
        marketConfig.marketplaceSettings.getMarketplaceFeePercentage() == offer.marketplaceFee &&
        offer.currencyAddress == _currencyAddress
      ) {
        // if original offer amount is greater than the new amount, refund the difference and set required amount to zero.
        if (offer.amount > _amount) {
          marketConfig.refund(_currencyAddress, offer.amount - _amount, offer.marketplaceFee, msg.sender);
          requiredAmount = 0;
        } else {
          // otherwise, set required amount to the difference of what was in the original offer.
          requiredAmount = requiredAmount - (offer.amount + ((offer.amount * offer.marketplaceFee) / 100));
        }
      } else {
        // refund whole amount if currencies or fee percentages do not match.
        marketConfig.refund(offer.currencyAddress, offer.amount, offer.marketplaceFee, msg.sender);
      }
    }

    MarketUtils.senderMustHaveMarketplaceApproved(_currencyAddress, requiredAmount);

    MarketUtils.checkAmountAndTransfer(_currencyAddress, requiredAmount);

    collectionOffers[msg.sender][_originContract] = IRareCollectionMarket.CollectionOffer(
      _currencyAddress,
      _amount,
      marketConfig.marketplaceSettings.getMarketplaceFeePercentage()
    );

    emit IRareCollectionMarket.CollectionOfferPlaced(msg.sender, _originContract, _currencyAddress, _amount);
  }

  /// @inheritdoc IRareCollectionMarket
  function acceptCollectionOffer(
    address _buyer,
    address _originContract,
    uint256 _tokenId,
    address _currencyAddress,
    uint256 _amount,
    address payable[] calldata _splitAddrs,
    uint8[] calldata _splitRatios
  ) external override nonReentrant notPaused {
    MarketUtils.senderMustBeTokenOwner(_originContract, _tokenId);
    MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    MarketUtils.checkSplits(_splitAddrs, _splitRatios);

    IRareCollectionMarket.CollectionOffer memory offer = collectionOffers[_buyer][_originContract];

    if (offer.amount == 0) revert IRareCollectionMarket.NoOfferExistsForBuyer(_originContract, _buyer);
    if (_amount != offer.amount) revert IRareCollectionMarket.IncorrectAmount(offer.amount, _amount);

    if (offer.currencyAddress != _currencyAddress)
      revert IRareCollectionMarket.CurrencyMismatch(_currencyAddress, offer.currencyAddress);

    delete collectionOffers[_buyer][_originContract];

    IERC721 erc721 = IERC721(_originContract);
    erc721.safeTransferFrom(msg.sender, _buyer, _tokenId);

    marketConfig.payout(_originContract, _tokenId, _currencyAddress, _amount, msg.sender, _splitAddrs, _splitRatios);

    marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);

    emit AcceptCollectionOffer(msg.sender, _buyer, _originContract, _currencyAddress, _amount, _tokenId);
  }

  /// @inheritdoc IRareCollectionMarket
  function cancelCollectionOffer(address _originContract) external nonReentrant notPaused {
    IRareCollectionMarket.CollectionOffer memory offer = collectionOffers[msg.sender][_originContract];

    if (offer.amount == 0) return;

    delete collectionOffers[msg.sender][_originContract];

    marketConfig.refund(offer.currencyAddress, offer.amount, offer.marketplaceFee, msg.sender);

    emit IRareCollectionMarket.CollectionOfferCancelled(msg.sender, _originContract);
  }

  /// @inheritdoc IRareCollectionMarket
  function setCollectionSalePrice(
    address _originContract,
    address _currencyAddress,
    uint256 _amount,
    address payable[] calldata _splitAddrs,
    uint8[] calldata _splitRatios
  ) external override notPaused {
    marketConfig.checkIfCurrencyIsApproved(_currencyAddress);
    MarketUtils.addressMustHaveMarketplaceApprovedForNFT(msg.sender, _originContract);
    MarketUtils.checkSplits(_splitAddrs, _splitRatios);

    if (_amount == 0) revert IRareCollectionMarket.AmountCantBeZero();

    collectionSalePrices[msg.sender][_originContract] = IRareCollectionMarket.CollectionSalePrice(
      _currencyAddress,
      _amount,
      _splitAddrs,
      _splitRatios
    );

    emit IRareCollectionMarket.CollectionSalePriceSet(msg.sender, _originContract, _currencyAddress, _amount);
  }

  /// @inheritdoc IRareCollectionMarket
  function cancelCollectionSalePrice(address _originContract) external notPaused {
    IRareCollectionMarket.CollectionSalePrice memory salePrice = collectionSalePrices[msg.sender][_originContract];

    if (salePrice.amount == 0) return;

    delete collectionSalePrices[msg.sender][_originContract];

    emit IRareCollectionMarket.CollectionSalePriceCancelled(msg.sender, _originContract);
  }

  /// @inheritdoc IRareCollectionMarket
  /// @dev Users will still need to cancel collection offers if previously placed.
  function buyFromCollection(
    address _originContract,
    uint256 _tokenId,
    address _currencyAddress,
    uint256 _amount
  ) external payable override nonReentrant notPaused {
    IERC721 erc721 = IERC721(_originContract);
    address tokenOwner = erc721.ownerOf(_tokenId);
    MarketUtils.addressMustHaveMarketplaceApprovedForNFT(tokenOwner, _originContract);

    uint256 requiredAmount = _amount + marketConfig.marketplaceSettings.calculateMarketplaceFee(_amount);

    IRareCollectionMarket.CollectionSalePrice memory salePrice = collectionSalePrices[tokenOwner][_originContract];

    if (salePrice.amount == 0) revert IRareCollectionMarket.SalePriceDoesntExist(tokenOwner, _originContract);

    if (salePrice.currencyAddress != _currencyAddress) {
      revert IRareCollectionMarket.CurrencyMismatch(_currencyAddress, salePrice.currencyAddress);
    }

    if (_amount != salePrice.amount) revert IRareCollectionMarket.IncorrectAmount(salePrice.amount, _amount);

    MarketUtils.checkAmountAndTransfer(_currencyAddress, requiredAmount);

    erc721.safeTransferFrom(tokenOwner, msg.sender, _tokenId);

    marketConfig.payout(
      _originContract,
      _tokenId,
      _currencyAddress,
      _amount,
      tokenOwner,
      salePrice.splitRecipients,
      salePrice.splitRatios
    );

    marketConfig.marketplaceSettings.markERC721Token(_originContract, _tokenId, true);

    emit Sold(tokenOwner, msg.sender, _originContract, _currencyAddress, _amount, _tokenId);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRareCollectionMarket
  function getCollectionOffer(
    address _originContract,
    address _buyer
  ) external view override returns (IRareCollectionMarket.CollectionOffer memory) {
    return collectionOffers[_buyer][_originContract];
  }

  /// @inheritdoc IRareCollectionMarket
  function getCollectionSalePrice(
    address _originContract,
    address _seller
  ) external view override returns (IRareCollectionMarket.CollectionSalePrice memory) {
    return collectionSalePrices[_seller][_originContract];
  }

  /// @notice Query the current market config being used.
  /// @return MarketConfig.Config struct with addresses for NetworkBeneficiary, MarketplaceSettings, SpaceOperatorRegistry, RoyaltyEngine, Payments, and ApprovedTokenRegistry.
  function getMarketConfig() external view returns (MarketConfig.Config memory) {
    return marketConfig;
  }

  /// @notice Query the contract to see the current pause status.
  /// @return bool flag on whether the contract is paused or not.
  function isPaused() external view returns (bool) {
    return paused;
  }
}
