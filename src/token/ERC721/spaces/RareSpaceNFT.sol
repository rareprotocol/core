// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC721Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from "openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC165Upgradeable} from "openzeppelin-contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TokenCreator} from "../../extensions/TokenCreator.sol";
import {Whitelist} from "../../extensions/Whitelist.sol";
import "../../extensions/ERC2981Upgradeable.sol";

/// @author koloz
/// @title RareSpaceNFT
/// @notice The 721 contract for the rarest of spaces.
contract RareSpaceNFT is
    OwnableUpgradeable,
    ERC165Upgradeable,
    ERC721Upgradeable,
    TokenCreator,
    ERC721BurnableUpgradeable,
    ERC2981Upgradeable,
    Whitelist
{
    mapping(uint256 => string) private tokenURIs;

    // Counter to keep track of the current token id.
    uint256 private tokenIdCounter;

    // Default royalty percentage
    uint256 public defaultRoyaltyPercentage;

    function init(
        string memory _name,
        string memory _symbol,
        address _operator
    ) public initializer {
        require(_operator != address(0));
        defaultRoyaltyPercentage = 10;

        __ERC721_init(_name, _symbol);
        __ERC165_init();

        super.transferOwnership(_operator);
    }

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(ownerOf(_tokenId) == msg.sender);
        _;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Upgradeable, ERC2981Upgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            interfaceId == 0x40c1a064 || super.supportsInterface(interfaceId);
    }

    function initWhitelist(
        address[] calldata _creators,
        uint256[] calldata _numMints
    ) external onlyOwner {
        require(_creators.length == _numMints.length);

        for (uint256 i = 0; i < _creators.length; i++) {
            _updateMintingAllowance(_creators[i], _numMints[i]);
        }
    }

    function toggleWhitelist(bool _enabled) external onlyOwner {
        _toggleWhitelist(_enabled);
    }

    function addToWhitelist(address _newAddress) external onlyOwner {
        _addToWhitelist(_newAddress);
    }

    function removeFromWhitelist(address _newAddress) external onlyOwner {
        _removeFromWhitelist(_newAddress);
    }

    function updateMintingAllowance(address _newAddress, uint256 _newAllowance)
        external
        onlyOwner
    {
        _updateMintingAllowance(_newAddress, _newAllowance);
    }

    function mintTo(
        string calldata _uri,
        address _receiver,
        address _royaltyReceiver
    ) external canMint(msg.sender, 1) {
        _createToken(
            _uri,
            msg.sender,
            _receiver,
            defaultRoyaltyPercentage,
            _royaltyReceiver
        );
    }

    function deleteToken(uint256 _tokenId) external onlyTokenOwner(_tokenId) {
        burn(_tokenId);
    }

    function setRoyaltyReceiver(uint256 _tokenId, address _receiver) external {
        require(msg.sender == tokenCreator(_tokenId), "Not creator");
        _setRoyaltyReceiver(_tokenId, _receiver);
    }

    function _createToken(
        string memory _uri,
        address _creator,
        address _receiver,
        uint256 _royaltyPercentage,
        address _royaltyReceiver
    ) internal returns (uint256) {
        tokenIdCounter++;
        _mint(_receiver, tokenIdCounter);
        tokenURIs[tokenIdCounter] = _uri;
        _setTokenCreator(tokenIdCounter, _creator);
        _setRoyaltyReceiver(tokenIdCounter, _royaltyReceiver);
        _setRoyaltyPercentage(tokenIdCounter, _royaltyPercentage);
        _decrementMintingAllowance(msg.sender);
        return tokenIdCounter;
    }
}
