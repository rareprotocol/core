// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author SuperRare Labs Inc.
/// @title IERC721Mint
/// @notice Interface for the RareMinter
interface IRareMinter {
  //////////////////////////////////////////////////////////////////////////
  //                      Events
  //////////////////////////////////////////////////////////////////////////
  event PrepareMintDirectSale(
    address indexed _contractAddress,
    address indexed _currency,
    address indexed _seller,
    uint256 _price,
    address payable[] splitRecipients,
    uint8[] splitRatios
  );

  event MintDirectSale(
    address indexed _contractAddress,
    address indexed _seller,
    address indexed _buyer,
    uint256 _tokenId,
    address _currency,
    uint256 _price
  );

  //////////////////////////////////////////////////////////////////////////
  //                        External Read Functions
  //////////////////////////////////////////////////////////////////////////

  /// @notice Gets the direct sale config for a contract
  /// @param _contractAddress address The address of the ERC721 contract
  /// @return address The address of the currency to accept
  function getDirectSaleConfig(
    address _contractAddress
  ) external view returns (address, address, uint256, address payable[] memory, uint8[] memory);

  //////////////////////////////////////////////////////////////////////////
  //                        External Write Functions
  //////////////////////////////////////////////////////////////////////////

  /// @notice Prepares a minting contract for direct sales
  /// @param _contractAddress address The address of the ERC721 contract
  /// @param _currencyAddress address The address of the currency to accept
  /// @param _price uint256 The price to mint each token
  /// @param _splitRecipients address payable[] The addresses to split the sale with
  /// @param _splitRatios uint8[] The ratios to split the sale with
  function prepareMintDirectSale(
    address _contractAddress,
    address _currencyAddress,
    uint256 _price,
    address payable[] calldata _splitRecipients,
    uint8[] calldata _splitRatios
  ) external;

  /// @notice Mints a token to the buyer
  /// @param _contractAddress address The address of the ERC721 contract
  /// @param _currencyAddress address The address of the currency
  /// @param _price uint256 The price to mint
  function mintDirectSale(address _contractAddress, address _currencyAddress, uint256 _price) external payable;
}
