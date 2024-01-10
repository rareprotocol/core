// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IRoyaltyRegistry, ICreatorRegistry} from "./interfaces/IRoyaltyRegistry.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";

contract RoyaltyRegistry is Ownable, AccessControl, IRoyaltyRegistry {
    bytes32 public constant ROYALTY_FEE_SETTER_ROLE =
        keccak256("ROYALTY_FEE_SETTER_ROLE");

    mapping(address => uint8) public contractRoyaltyPercentage;

    mapping(address => bool) public contractRoyaltyPercentageSet;

    mapping(address => address) public royaltyReceiverOverride;

    mapping(address => address) public contractRoyaltyReceiver;

    mapping(address => mapping(uint256 => address)) public tokenRoyaltyReceiver;

    ICreatorRegistry public iERC721TokenCreator;

    constructor(address _iERC721TokenCreator) {
        require(
            _iERC721TokenCreator != address(0),
            "constructor::_iERC721TokenCreator cannot be the zero address"
        );
        _setupRole(AccessControl.DEFAULT_ADMIN_ROLE, _msgSender());
        iERC721TokenCreator = ICreatorRegistry(_iERC721TokenCreator);
    }

    function setIERC721TokenCreator(address _contractAddress)
        external
        onlyOwner
    {
        require(
            _contractAddress != address(0),
            "setIERC721TokenCreator::_contractAddress cannot be null"
        );

        iERC721TokenCreator = ICreatorRegistry(_contractAddress);
    }

    function getERC721TokenRoyaltyPercentage(
        address _contractAddress,
        uint256 //_tokenId
    ) public view override returns (uint8) {
        return
            contractRoyaltyPercentageSet[_contractAddress]
                ? contractRoyaltyPercentage[_contractAddress]
                : 10;
    }

    function getPercentageForSetERC721ContractRoyalty(address _contractAddress)
        external
        view
        returns (uint8)
    {
        return
            contractRoyaltyPercentageSet[_contractAddress]
                ? contractRoyaltyPercentage[_contractAddress]
                : 10;
    }

    function setPercentageForSetERC721ContractRoyalty(
        address _contractAddress,
        uint8 _percentage
    ) external override {
        require(
            hasRole(ROYALTY_FEE_SETTER_ROLE, _msgSender()),
            "setPercentageForSetERC721ContractRoyalty::Caller must have royalty fee setter role"
        );
        require(
            _percentage <= 100,
            "setPercentageForSetERC721ContractRoyalty::_percentage must be <= 100"
        );
        contractRoyaltyPercentage[_contractAddress] = _percentage;
        contractRoyaltyPercentageSet[_contractAddress] = true;
    }

    function calculateRoyaltyFee(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external view override returns (uint256) {
        return
            (_amount *
                getERC721TokenRoyaltyPercentage(_contractAddress, _tokenId)) /
            100;
    }

    function tokenCreator(address _contractAddress, uint256 _tokenId)
        external
        view
        override
        returns (address payable)
    {
        address creator = iERC721TokenCreator.tokenCreator(
            _contractAddress,
            _tokenId
        );

        creator = contractRoyaltyReceiver[_contractAddress] != address(0)
            ? contractRoyaltyReceiver[_contractAddress]
            : creator;

        creator = tokenRoyaltyReceiver[_contractAddress][_tokenId] != address(0)
            ? tokenRoyaltyReceiver[_contractAddress][_tokenId]
            : creator;

        return
            royaltyReceiverOverride[creator] != address(0)
                ? payable(royaltyReceiverOverride[creator])
                : payable(creator);
    }

    function setRoyaltyReceiverOverride(address _receiver) external {
        require(
            _receiver != address(0),
            "setRoyaltyReceiverOverride::cant set to zero address"
        );

        royaltyReceiverOverride[msg.sender] = _receiver;
    }

    function setRoyaltyReceiverForContract(
        address _receiver,
        address _contractAddress
    ) external {
        require(
            _receiver != address(0) && _contractAddress != address(0),
            "setRoyaltyReceiverOverride::cant set to zero address"
        );

        Ownable ownableContract = Ownable(_contractAddress);

        try ownableContract.owner() returns (address owner) {
            require(
                msg.sender == owner,
                "setRoyaltyReceiverForContract::must be owner of contract"
            );
            contractRoyaltyReceiver[_contractAddress] = _receiver;
        } catch {
            revert("setRoyaltyReceiverForContract::contract has no owner");
        }
    }

    function setRoyaltyReceiverForToken(
        address _receiver,
        address _contractAddress,
        uint256 _tokenId
    ) external {
        address creator = iERC721TokenCreator.tokenCreator(
            _contractAddress,
            _tokenId
        );

        require(
            msg.sender == creator,
            "setRoyaltyReceiverForToken::must be token creator"
        );

        tokenRoyaltyReceiver[_contractAddress][_tokenId] = _receiver;
    }
}
