// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author SuperRare Labs Inc.
/// @title IBatchOffer
/// @notice Interface for the RareMinter
interface IBatchOffer {
  //////////////////////////////////////////////////////////////////////////
  //                      Structs
  //////////////////////////////////////////////////////////////////////////

  struct BatchOffer {
    address creator;
    bytes32 rootHash;
    uint256 amount;
    address currency;
    uint256 expiry;
    uint256 feePercentage;
  }

  /*//////////////////////////////////////////////////////////////////////////
                      Events
  //////////////////////////////////////////////////////////////////////////*/
  event BatchOfferCreated(address indexed creator, bytes32 rootHash, uint256 amount, address currency, uint256 expiry);

  event BatchOfferAccepted(
    address indexed seller,
    address indexed buyer,
    address indexed contractAddress,
    uint256 tokenId,
    bytes32 rootHash,
    address currency,
    uint256 amount
  );
}
