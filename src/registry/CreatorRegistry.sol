// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC165Checker} from "openzeppelin-contracts/utils/introspection/ERC165Checker.sol";
import {ICreatorRegistry} from "./interfaces/ICreatorRegistry.sol";
import {ITokenCreator} from "../token/extensions/ITokenCreator.sol";

contract CreatorRegistry is Ownable, ICreatorRegistry {
    bytes4 private constant ERC721_CREATOR_INTERFACE_ID = 0x40c1a064;

    mapping(address => bool) private implementsIERC721Creator;

    mapping(address => address) private creatorOverrides;

    event CreatorOverrideCreated(address indexed from, address indexed to);

    constructor(address[] memory iERC721CreatorImplementations) {
        require(
            iERC721CreatorImplementations.length < 1000,
            "constructor::Cannot mark more than 1000 addresses as IERC721Creator"
        );

        for (uint8 i = 0; i < iERC721CreatorImplementations.length; i++) {
            if (iERC721CreatorImplementations[i] != address(0)) {
                implementsIERC721Creator[
                    iERC721CreatorImplementations[i]
                ] = true;
            }
        }
    }

    function tokenCreator(address _contractAddress, uint256 _tokenId)
        external
        view
        override
        returns (address payable)
    {
        address payable creator = payable(address(0));

        if (
            ERC165Checker.supportsInterface(
                _contractAddress,
                ERC721_CREATOR_INTERFACE_ID
            ) || implementsIERC721Creator[_contractAddress]
        ) {
            creator = payable(
                ITokenCreator(_contractAddress).tokenCreator(_tokenId)
            );
        }

        if (creator == address(0)) {
            return creator;
        }

        if (creatorOverrides[creator] != address(0)) {
            return payable(creatorOverrides[creator]);
        }

        return creator;
    }

    function overrideCreator(
        address oldCreatorAddress,
        address newCreatorAddress
    ) external onlyOwner {
        require(
            oldCreatorAddress != address(0),
            "overrideCreator::oldCreatorAddress cannot be null"
        );
        require(
            newCreatorAddress != address(0),
            "overrideCreator::newCreatorAddress cannot be null"
        );
        creatorOverrides[oldCreatorAddress] = newCreatorAddress;
        emit CreatorOverrideCreated(oldCreatorAddress, newCreatorAddress);
    }

    function setIERC721Creator(address contractAddress) external onlyOwner {
        require(
            contractAddress != address(0),
            "setIERC721Creator::_contractAddress cannot be null"
        );

        implementsIERC721Creator[contractAddress] = true;
    }
}
