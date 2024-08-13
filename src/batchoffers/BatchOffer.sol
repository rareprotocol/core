// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ensdomains/governance/MerkleProof.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/interfaces/IERC721.sol";

contract BatchOffer is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using MarketUtils for MarketConfig.Config;
    using MarketConfig for MarketConfig.Config;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /*//////////////////////////////////////////////////////////////////////////
                        Structs and Storage
    //////////////////////////////////////////////////////////////////////////*/
    MarketConfig.Config private marketConfig;
    
    struct BatchOffer {
        address creator;
        bytes32 rootHash;
    }

    mapping(bytes32 =>  BatchOffer) private _rootToOffer;

    EnumerableSet.Bytes32Set private _roots;

    //////////////////////////////////////////////////////////////////////////
  //                      Initializer
  //////////////////////////////////////////////////////////////////////////
  function initialize(
    address _networkBeneficiary,
    address _marketplaceSettings,
    address _royaltyEngine,
    address _payments,
    address _approvedTokenRegistry
  ) external initializer {
    marketConfig = MarketConfig.generateMarketConfig(
      _networkBeneficiary,
      _marketplaceSettings,
      _royaltyEngine,
      _payments,
      _approvedTokenRegistry
    );
    __Ownable_init();
  }

    /*//////////////////////////////////////////////////////////////////////////
                        Events
    //////////////////////////////////////////////////////////////////////////*/
    event BatchOfferCreated(
        address indexed creator,
        bytes32 rootHash,
        uint256 expiry
    );

    event BatchOfferAccepted(
        address indexed seller,
        address indexed buyer,
        address indexed contractAddress,
        uint256 tokenId,
        bytes32 rootHash,
        address currency,
        uint256 amount
    );
    

    /*//////////////////////////////////////////////////////////////////////////
                        External Write Functions
    //////////////////////////////////////////////////////////////////////////*/
    function createBatchOffer(
        bytes32 _rootHash
    ) external {
        require(
            _rootToOffer[_rootHash].creator == address(0),
            "createBatchOffer::offer already exists"
        );

        // Approved Currency Check
        marketConfig.checkIfCurrencyIsApproved(_currencyAddress);

        _rootToOffer[_rootHash] = BatchOffer(msg.sender, _rootHash);
        _roots.add(_rootHash);
        emit BatchOfferCreated(msg.sender, _rootHash);
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
        require(msg.sender == tokenOwner, "acceptBatchOffer::Must be tokenOwner to accept offer");

        BatchOfferOrder memory offer = _rootToOffer[_rootHash];
        require(offer.creator != address(0), "acceptBatchOffer::offer does not exist");
        bytes32 leaf = keccak256(
            abi.encodePacked(_contractAddress, _tokenId, _amount, _currency)
        );
        (bool success, ) = MerkleProof.verify(_proof, offer.rootHash, leaf);
        require(success, "Invalid _proof");
        _roots.remove(_rootHash);
        delete _rootToOffer[_rootHash];

        // Perform payout
        if (directSaleConfig.price != 0) {
            marketConfig.payout(
                _contractAddress,
                _tokenId,
                _currency,
                _amount,
                msg.sender,
                _splitRecipients,
                _splitRatios
            );
        }

        // Transfer ERC721 token from the seller to the buyer
        IERC721 erc721Token = IERC721(_contractAddress);
        require(erc721Token.ownerOf(_tokenId) == msg.sender, "acceptBatchOffer:: Must be owner of the token being sold");
        erc721Token.safeTransferFrom(msg.sender, offer.creator, _tokenId);
        emit PodFullfilled(
            msg.sender,
            offer.creator,
            _contractAddress,
            _tokenId,
            _rootHash,
            _currency,
            _amount
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                        External Read Functions
    //////////////////////////////////////////////////////////////////////////*/

    // Getter function for _rootToOffer mapping
    function getBatchOffer(
        bytes32 rootHash
    ) external view returns (BatchOffer memory) {
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
