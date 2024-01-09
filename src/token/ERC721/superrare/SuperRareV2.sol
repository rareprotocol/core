// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {TokenCreator} from "../../extensions/TokenCreator.sol";
import {Whitelist} from "./Whitelist.sol";
import {ISuperRare} from "./ISuperRare.sol";

contract SuperRareV2 is ERC721, TokenCreator, Ownable, Whitelist {
    mapping(uint256 => string) private _tokenURIs;

    // Counter for creating token IDs
    uint256 private idCounter;

    // Old SuperRare contract to look up token details.
    ISuperRare private oldSuperRare;

    // Event indicating metadata was updated.
    event TokenURIUpdated(uint256 indexed _tokenId, string _uri);

    constructor(string memory _name, string memory _symbol)
        // address _oldSuperRare
        ERC721(_name, _symbol)
    {
        // Get reference to old SR contract.
        // oldSuperRare = ISuperRare(_oldSuperRare);

        // uint256 oldSupply = oldSuperRare.totalSupply();
        // Set id counter to be continuous with SuperRare.
        // idCounter = oldSupply + 1;
        idCounter = 0;
    }

    /**
     * @dev Whitelists a bunch of addresses.
     * @param _whitelistees address[] of addresses to whitelist.
     */
    function initWhitelist(address[] memory _whitelistees) public onlyOwner {
        // Add all whitelistees.
        for (uint256 i = 0; i < _whitelistees.length; i++) {
            address creator = _whitelistees[i];
            if (!isWhitelisted(creator)) {
                _whitelist(creator);
            }
        }
    }

    /**
     * @dev Checks that the token is owned by the sender.
     * @param _tokenId uint256 ID of the token.
     */
    modifier onlyTokenOwner(uint256 _tokenId) {
        address owner = ownerOf(_tokenId);
        require(owner == msg.sender, "must be the owner of the token");
        _;
    }

    /**
     * @dev Checks that the token was created by the sender.
     * @param _tokenId uint256 ID of the token.
     */
    modifier onlyTokenCreator(uint256 _tokenId) {
        address creator = tokenCreator(_tokenId);
        require(creator == msg.sender, "must be the creator of the token");
        _;
    }

    /**
     * @dev Adds a new unique token to the supply.
     * @param _uri string metadata uri associated with the token.
     */
    function addNewToken(string memory _uri) public {
        require(
            isWhitelisted(msg.sender),
            "must be whitelisted to create tokens"
        );
        _createToken(_uri, msg.sender);
    }

    /**
     * @dev Deletes the token with the provided ID.
     * @param _tokenId uint256 ID of the token.
     */
    function deleteToken(uint256 _tokenId) public onlyTokenOwner(_tokenId) {
        _burn(_tokenId);
    }

    /**
     * @dev Updates the token metadata if the owner is also the
     *      creator.
     * @param _tokenId uint256 ID of the token.
     * @param _uri string metadata URI.
     */
    function updateTokenMetadata(uint256 _tokenId, string memory _uri)
        public
        onlyTokenOwner(_tokenId)
        onlyTokenCreator(_tokenId)
    {
        _setTokenURI(_tokenId, _uri);
        emit TokenURIUpdated(_tokenId, _uri);
    }

    /**
     * @dev Internal function creating a new token.
     * @param _uri string metadata uri associated with the token
     * @param _creator address of the creator of the token.
     */
    function _createToken(string memory _uri, address _creator)
        internal
        returns (uint256)
    {
        uint256 newId = idCounter;
        idCounter++;
        _mint(_creator, newId);
        _setTokenURI(newId, _uri);
        _setTokenCreator(newId, _creator);
        return newId;
    }

    function _setTokenURI(uint256 _tokenId, string memory _uri) internal {
        _tokenURIs[_tokenId] = _uri;
    }
}
