// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {MarketConfig} from "../utils/structs/MarketConfig.sol";
import {MarketUtils} from "../utils/MarketUtils.sol";
import {IERC721Mint} from "./IERC721Mint.sol";
import {IRareMinter} from "./IRareMinter.sol";

/// @author SuperRareLabs Inc.
/// @title RareMinter
/// @notice The logic for all functions related to the RareMinter.
contract RareMinter is Initializable, IRareMinter, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
  using MarketUtils for MarketConfig.Config;
  using MarketConfig for MarketConfig.Config;

  //////////////////////////////////////////////////////////////////////////
  //                      Private Storage
  //////////////////////////////////////////////////////////////////////////

  // Config for the market actions
  MarketConfig.Config private marketConfig;

  // Mapping of contract address to direct sale config
  mapping(address => DirectSaleConfig) private directSaleConfigs;

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

  //////////////////////////////////////////////////////////////////////////
  //                      External Read Functions
  //////////////////////////////////////////////////////////////////////////
  function getDirectSaleConfig(address _contractAddress) external view returns (DirectSaleConfig memory) {
    return directSaleConfigs[_contractAddress];
  }

  //////////////////////////////////////////////////////////////////////////
  //                      External Write Functions
  //////////////////////////////////////////////////////////////////////////
  function prepareMintDirectSale(
    address _contractAddress,
    address _currencyAddress,
    uint256 _price,
    uint256 _startTime,
    address payable[] calldata _splitRecipients,
    uint8[] calldata _splitRatios
  ) external {
    require(
      OwnableUpgradeable(_contractAddress).owner() == msg.sender,
      "prepareMintDirectSale::Only mint contract owner can prepare the mint"
    );
    directSaleConfigs[_contractAddress] = DirectSaleConfig(
      msg.sender,
      _currencyAddress,
      _price,
      _startTime,
      _splitRecipients,
      _splitRatios
    );
    emit PrepareMintDirectSale(_contractAddress, _currencyAddress, msg.sender, _price, _splitRecipients, _splitRatios);
  }

  function mintDirectSale(
    address _contractAddress,
    address _currencyAddress,
    uint256 _price,
    uint8 _numMints
  ) external payable {
    DirectSaleConfig memory directSaleConfig = directSaleConfigs[_contractAddress];
    // Perform checks
    require(_numMints > 0, "mintDirectSale::Mints must be greater than 0");
    require(directSaleConfig.startTime <= block.timestamp, "mintDirectSale::Sale has not started");
    require(directSaleConfig.seller != address(0), "mintDirectSale::Contract not prepared for direct sale");
    require(_price == directSaleConfig.price, "mintDirectSale::Price does not match required price");
    require(
      directSaleConfig.currencyAddress == _currencyAddress,
      "mintDirectSale::Currency does not match required currency"
    );
    uint256 totalPrice = _numMints * _price;
    // Check amount
    if (directSaleConfig.price != 0) {
      uint256 requiredAmount = totalPrice + marketConfig.marketplaceSettings.calculateMarketplaceFee(totalPrice);
      MarketUtils.checkAmountAndTransfer(_currencyAddress, requiredAmount);
    }

    // Perform Mint
    uint256 tokenIdStart = IERC721Mint(_contractAddress).mintTo(msg.sender); // get first Token Id in range of mint
    try marketConfig.marketplaceSettings.markERC721Token(_contractAddress, tokenIdStart, true) {} catch {}
    for (uint256 i = 1; i < _numMints; i++) {
      // Start with offset of 1 since already minted first
      IERC721Mint(_contractAddress).mintTo(msg.sender);
      try marketConfig.marketplaceSettings.markERC721Token(_contractAddress, tokenIdStart + i, true) {} catch {}
    }

    // Perform payout
    if (directSaleConfig.price != 0) {
      marketConfig.payout(
        _contractAddress,
        tokenIdStart,
        _currencyAddress,
        totalPrice,
        directSaleConfig.seller,
        directSaleConfig.splitRecipients,
        directSaleConfig.splitRatios
      );
    }

    emit MintDirectSale(
      _contractAddress,
      directSaleConfig.seller,
      msg.sender,
      tokenIdStart,
      tokenIdStart + _numMints - 1,
      _currencyAddress,
      _price
    );
  }

  //////////////////////////////////////////////////////////////////////////
  //                      Internal UUPS Functions
  //////////////////////////////////////////////////////////////////////////
  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}

  //////////////////////////////////////////////////////////////////////////
  //                      Admin Write Functions
  //////////////////////////////////////////////////////////////////////////
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
}
