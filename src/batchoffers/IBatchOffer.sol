// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author SuperRare Labs Inc.
/// @title IBatchOffer
/// @notice Interface for the RareMinter
interface IBatchOffer {
  //////////////////////////////////////////////////////////////////////////
  //                      Structs
  //////////////////////////////////////////////////////////////////////////



/*//////////////////////////////////////////////////////////////////////////
                    Events
//////////////////////////////////////////////////////////////////////////*/
event BatchOfferCreated (
    address indexed creator,
    bytes32 rootHash
);

event BatchOfferAccepted (
    address indexed seller,
    address indexed buyer,
    address indexed contractAddress,
    uint256 tokenId,
    bytes32 rootHash,
    address currency,
    uint256 amount
);
}