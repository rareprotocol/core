// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ensdomains/governance/MerkleProof.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {IERC721} from "openzeppelin-contracts/interfaces/IERC721.sol";

contract GlobalOffer is Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /*//////////////////////////////////////////////////////////////////////////
                        Structs and Storage
    //////////////////////////////////////////////////////////////////////////*/
    struct GlobalOffer {
        address creator;
        bytes32 rootHash;
    }

    mapping(bytes32 =>  GlobalOffer) private _rootToOffer;

    EnumerableSet.Bytes32Set private _roots;


    /*//////////////////////////////////////////////////////////////////////////
                        Events
    //////////////////////////////////////////////////////////////////////////*/
    event GlobalOfferCreated(

        address indexed creator,
        bytes32 rootHash
    );

    event GlobalOfferAccepted(
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
    function createGlobalOffer(
        bytes32 _rootHash
    ) external {
        require(
            _rootToOffer[_rootHash].creator == address(0),
            "[createGlobalOffer] offer already exists"
        );
        _rootToOffer[_rootHash] = GlobalOffer(msg.sender, _rootHash);
        _roots.add(_rootHash);
        emit GlobalOfferCreated(msg.sender, _rootHash);
    }

    function fulfillGlobalOffer(
        bytes32[] memory _proof,
        bytes32 _rootHash,
        address _contractAddress,
        uint256 _tokenId,
        address _currency,
        uint256 _amount
    ) external {
        GlobalOfferOrder memory offer = _rootToOffer[_rootHash];
        require(offer.creator != address(0), "[fulfillGlobalOffer] offer does not exist");
        bytes32 leaf = keccak256(
            abi.encodePacked(_contractAddress, _tokenId, _amount, _currency)
        );
        (bool success, ) = MerkleProof.verify(_proof, offer.rootHash, leaf);
        require(success, "Invalid _proof");
        _roots.remove(_rootHash);
        delete _rootToOffer[_rootHash];

        // Transfer ERC20 tokens from the buyer to the seller
        IERC20 erc20Token = IERC20(_currency);
        require(
            erc20Token.transferFrom(offer.creator, owner(), _amount * 3_00 / 100_00),
            "ERC20 transfer failed"
        );
        require(
            erc20Token.transferFrom(offer.creator, msg.sender, _amount),
            "ERC20 transfer failed"
        );

        // Transfer ERC721 token from the seller to the buyer
        IERC721 erc721Token = IERC721(_contractAddress);
        require(erc721Token.ownerOf(_tokenId) == msg.sender, "[fulfillGlobalOffer] Must be owner of the token being sold");
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
    function getGlobalOffer(
        bytes32 rootHash
    ) external view returns (GlobalOffer memory) {
        return _rootToOffer[rootHash];
    }

    // Setter function for _rootToOffer mapping
    function setGlobalOffer(bytes32 rootHash, GlobalOffer memory order) external {
        _rootToOffer[rootHash] = order;
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
