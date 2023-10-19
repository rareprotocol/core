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
  function getDirectSaleConfig(
    address _contractAddress
  ) external view returns (DirectSaleConfig memory) {
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

  function mintDirectSale(address _contractAddress, address _currencyAddress, uint256 _price) external payable {
    DirectSaleConfig memory directSaleConfig = directSaleConfigs[_contractAddress];
    // Perform checks
    require(directSaleConfig.startTime <= block.timestamp, "mintDirectSale::Sale has not started");
    require(directSaleConfig.seller != address(0), "mintDirectSale::Contract not prepared for direct sale");
    require(_price == directSaleConfig.price, "mintDirectSale::Price does not match required price");
    require(
      directSaleConfig.currencyAddress == _currencyAddress,
      "mintDirectSale::Currency does not match required currency"
    );

    // If free mint, ignore payout
    if (directSaleConfig.price == 0) {
      uint256 tokenIdFreeMint = IERC721Mint(_contractAddress).mintTo(msg.sender);
      try marketConfig.marketplaceSettings.markERC721Token(_contractAddress, tokenIdFreeMint, true) {} catch {}
      emit MintDirectSale(_contractAddress, directSaleConfig.seller, msg.sender, tokenIdFreeMint, _currencyAddress, _price);
      return;
    }

    // Check amount 
    uint256 requiredAmount = _price + marketConfig.marketplaceSettings.calculateMarketplaceFee(_price);
    MarketUtils.checkAmountAndTransfer(_currencyAddress, requiredAmount);

    // Mint the token
    uint256 tokenId = IERC721Mint(_contractAddress).mintTo(msg.sender);

    // Perform payout
    marketConfig.payout(
      _contractAddress,
      tokenId,
      _currencyAddress,
      _price,
      directSaleConfig.seller,
      directSaleConfig.splitRecipients,
      directSaleConfig.splitRatios
    );

    // Attempt to mark token as sold. If not ignore
    try marketConfig.marketplaceSettings.markERC721Token(_contractAddress, tokenId, true) {} catch {}

    emit MintDirectSale(_contractAddress, directSaleConfig.seller, msg.sender, tokenId, _currencyAddress, _price);
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
