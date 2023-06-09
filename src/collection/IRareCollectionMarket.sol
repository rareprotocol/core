// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRareCollectionMarket {
  /*//////////////////////////////////////////////////////////////////////////
                                Structs
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice A struct to store information about a collection offer.
  /// @dev Contract Address and Buyer Address omitted to reduce redundancy as they're part of the mapping.
  /// @dev Returned by {getCollectionOffer} method.
  struct CollectionOffer {
    address currencyAddress;
    uint256 amount;
    uint256 marketplaceFee;
  }

  /// @notice A struct to store information about a collection sale price.
  /// @dev Contract Address and Buyer Address omitted to reduce redundancy as they're part of the mapping.
  /// @dev Returned by {getCollectionSalePrice} method.
  struct CollectionSalePrice {
    address currencyAddress;
    uint256 amount;
    address payable[] splitRecipients;
    uint8[] splitRatios;
  }

  /*//////////////////////////////////////////////////////////////////////////
                              Events
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when the a collection offer is placed via {makeCollectionOffer}.
  event CollectionOfferPlaced(
    address indexed _buyer,
    address indexed _originContract,
    address indexed _currencyAddress,
    uint256 _amount
  );

  /// @notice Emitted when a collection offer is cancelled via {cancelCollectionOffer}.
  event CollectionOfferCancelled(address indexed _buyer, address indexed _originContract);

  /// @notice Emitted when a collection sale price is set via {setCollectionSalePrice}.
  event CollectionSalePriceSet(
    address indexed _seller,
    address indexed _originContract,
    address indexed _currencyAddress,
    uint256 _amount
  );

  /// @notice Emitted when a collection sale price has been cancelled via {cancelCollectionSalePrice}.
  event CollectionSalePriceCancelled(address indexed _seller, address indexed _originContract);

  /// @notice Emitted when a token is bought from a sale price via {buyFromCollection}.
  event Sold(
    address indexed _seller,
    address indexed _buyer,
    address indexed _originContract,
    address _currencyAddress,
    uint256 _amount,
    uint256 _tokenId
  );

  /// @notice Emitted when a collection offer is accepted via {acceptCollectionOffer}.
  event AcceptCollectionOffer(
    address indexed _seller,
    address indexed _buyer,
    address indexed _originContract,
    address _currencyAddress,
    uint256 _amount,
    uint256 _tokenId
  );

  /*//////////////////////////////////////////////////////////////////////////
                            Custom Errors
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when an offer or sale price with an amount of 0 is made via {makeCollectionOffer} and {setCollectionSalePrice}.
  error AmountCantBeZero();

  /// @notice Emitted when a sale price has an invalid token range.
  error InvalidTokenRange();

  /// @notice Emitted via {acceptCollectionOffer} if no offer exists on {_originContract} for {_buyer}.
  error NoOfferExistsForBuyer(address _originContract, address _buyer);

  /// @notice Emitted via {buyFromCollection} if no sale price exists for {_originContract} and {_seller}.
  error SalePriceDoesntExist(address _seller, address _originContract);

  /// @notice Emitted via {buyFromCollection} if the token is not in the sale price range.
  error TokenNotPartOfSalePrice(
    address _seller,
    address _originContract,
    uint256 _tokenId
  );

  /// @notice Emitted via {acceptCollectionOffer} and {buyFromCollection} when the required amount isnt sent.
  error IncorrectAmount(uint256 _requiredAmount, uint256 _specifiedAmount);

  /// @notice Emitted via {buyFromCollection} and {acceptCollectionOffer} when the currency address doesnt match the sale price/offer.
  error CurrencyMismatch(address _suppliedCurrency, address _configuredCurrency);

  /// @notice Emitted via functions if the contract has been paused.
  error ContractPaused();

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Place an offer for a collection that can be accepted by any token owner.
  /// @param _originContract Address of the collection the offer is placed on.
  /// @param _currencyAddress Address of the token being offered.
  /// @param _amount Amount being offered.
  function makeCollectionOffer(
    address _originContract,
    address _currencyAddress,
    uint256 _amount
  ) external payable;

  /// @notice Accept a collection offer that as made.
  /// @param _buyer Address of the user who submitted the collection offer.
  /// @param _originContract Contract of the asset the offer was made on.
  /// @param _tokenId TokenId of the asset.
  /// @param _currencyAddress Address of the currency used for the offer.
  /// @param _amount Amount the offer was for/and is being accepted.
  /// @param _splitAddrs Addresses to split the sellers commission with.
  /// @param _splitRatios The ratio for the split corresponding to each of the addresses being split with.
  function acceptCollectionOffer(
    address _buyer,
    address _originContract,
    uint256 _tokenId,
    address _currencyAddress,
    uint256 _amount,
    address payable[] calldata _splitAddrs,
    uint8[] calldata _splitRatios
  ) external;

  /// @notice Cancels an existing collection offer the sender has placed.
  /// @param _originContract Contract address of collection.
  function cancelCollectionOffer(address _originContract) external;

  /// @notice Set a sale price for all pieces under {_originContract}.
  /// @param _originContract Contract address of the collection being listed.
  /// @param _currencyAddress Contract address of the currency the collection is being listed for.
  /// @param _amount Amount of the currency the asset is being listed for (including all decimal points).
  /// @param _splitAddrs Addresses to split the sellers commission with.
  /// @param _splitRatios The ratio for the split corresponding to each of the addresses being split with.
  function setCollectionSalePrice(
    address _originContract,
    address _currencyAddress,
    uint256 _amount,
    address payable[] calldata _splitAddrs,
    uint8[] calldata _splitRatios
  ) external;

  /// @notice Cancels an existing collection sale price set by the sender.
  /// @param _originContract Contract address of the collection.
  function cancelCollectionSalePrice(address _originContract) external;

  /// @notice Purchase token under the current owners collection sale price.
  /// @param _originContract Contract address for asset being bought.
  /// @param _tokenId TokenId of asset being bought.
  /// @param _currencyAddress Currency address of asset being used to buy.
  /// @param _amount Amount the piece if being bought for (excluding marketplace fee).
  function buyFromCollection(
    address _originContract,
    uint256 _tokenId,
    address _currencyAddress,
    uint256 _amount
  ) external payable;

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Queries the collection offer made on {_originContract} by {_buyer}.
  /// @param _originContract The nft contract the collection offer was made on.
  /// @param _buyer The user who placed the collection offer.
  /// @return CollectionOffer struct containing the currencyAddress, amount, and marketplace fee.
  function getCollectionOffer(address _originContract, address _buyer)
    external
    view
    returns (IRareCollectionMarket.CollectionOffer memory);

  /// @notice Queries the collection sales price set on {_originContract} by {_seller}.
  /// @param _originContract The nft contract the collection sales price was set on.
  /// @param _seller The user who set the collection sales price.
  /// @return CollectionSalePrice struct containing the currencyAddress, amount, token range, and split information.
  function getCollectionSalePrice(address _originContract, address _seller)
    external
    view
    returns (IRareCollectionMarket.CollectionSalePrice memory);
}
