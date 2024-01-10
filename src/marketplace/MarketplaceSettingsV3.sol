// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IMarketplaceSettings} from "./IMarketplaceSettings.sol";
import {MarketplaceSettingsV2} from "./MarketplaceSettingsV2.sol";
import {IStakingSettings} from "./IStakingSettings.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {IERC721} from "openzeppelin-contracts/token/ERC721/IERC721.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract MarketplaceSettingsV3 is
    Ownable,
    AccessControl,
    IMarketplaceSettings,
    IStakingSettings
{
    uint8 private stakingFeePercentage;
    bytes32 public constant TOKEN_MARK_ROLE = keccak256("TOKEN_MARK_ROLE");

    // This is meant to be the MarketplaceSettings contract located in the V1 folder
    MarketplaceSettingsV2 private oldMarketplaceSettings;

    // EnumerableSet library method
    using EnumerableSet for EnumerableSet.AddressSet;

    // EnumerableSet of contracts marked sold
    EnumerableSet.AddressSet private contractSold;

    uint256 private maxValue;
    uint256 private minValue;

    uint8 private marketplaceFeePercentage;
    uint8 private primarySaleFeePercentage;

    constructor(address newOwner, address oldSettings) {
        maxValue = 2**254;
        minValue = 1000;
        marketplaceFeePercentage = 3;
        primarySaleFeePercentage = 15;
        stakingFeePercentage = 0;

        require(
            newOwner != address(0),
            "constructor::New owner address cannot be null"
        );

        require(
            oldSettings != address(0),
            "constructor::Old Marketplace Settings address cannot be null"
        );

        _setupRole(AccessControl.DEFAULT_ADMIN_ROLE, newOwner);
        _setupRole(TOKEN_MARK_ROLE, newOwner);
        transferOwnership(newOwner);

        oldMarketplaceSettings = MarketplaceSettingsV2(oldSettings);
    }

    function grantMarketplaceAccess(address _account) external {
        require(
            hasRole(AccessControl.DEFAULT_ADMIN_ROLE, _msgSender()),
            "grantMarketplaceAccess::Must be admin to call method"
        );
        grantRole(TOKEN_MARK_ROLE, _account);
    }

    function getMarketplaceMaxValue() external view override returns (uint256) {
        return maxValue;
    }

    function setPrimarySaleFeePercentage(uint8 _primarySaleFeePercentage)
        external
        onlyOwner
    {
        primarySaleFeePercentage = _primarySaleFeePercentage;
    }

    function setMarketplaceMaxValue(uint256 _maxValue) external onlyOwner {
        maxValue = _maxValue;
    }

    function getMarketplaceMinValue() external view override returns (uint256) {
        return minValue;
    }

    function setMarketplaceMinValue(uint256 _minValue) external onlyOwner {
        minValue = _minValue;
    }

    function getMarketplaceFeePercentage()
        external
        view
        override
        returns (uint8)
    {
        return marketplaceFeePercentage;
    }

    function setMarketplaceFeePercentage(uint8 _percentage) external onlyOwner {
        require(
            _percentage <= 100,
            "setMarketplaceFeePercentage::_percentage must be <= 100"
        );
        marketplaceFeePercentage = _percentage;
    }

    function calculateMarketplaceFee(uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        return (_amount * marketplaceFeePercentage) / 100;
    }

    function getERC721ContractPrimarySaleFeePercentage(address)
        external
        view
        override
        returns (uint8)
    {
        return primarySaleFeePercentage;
    }

    function setERC721ContractPrimarySaleFeePercentage(
        address _contractAddress,
        uint8 _percentage
    ) external override {}

    function calculatePrimarySaleFee(address, uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        return (_amount * primarySaleFeePercentage) / 100;
    }

    function hasERC721TokenSold(address _contractAddress, uint256 _tokenId)
        external
        view
        override
        returns (bool)
    {
        bool contractHasSold = contractSold.contains(_contractAddress);

        if (contractHasSold) return true;

        return
            oldMarketplaceSettings.hasERC721TokenSold(
                _contractAddress,
                _tokenId
            );
    }

    function markERC721Token(
        address _contractAddress,
        uint256 _tokenId,
        bool _hasSold
    ) public override {
        require(
            hasRole(TOKEN_MARK_ROLE, msg.sender),
            "markERC721Token::Must have TOKEN_MARK_ROLE role to call method"
        );
        oldMarketplaceSettings.markERC721Token(
            _contractAddress,
            _tokenId,
            _hasSold
        );
    }

    function markTokensAsSold(
        address _originContract,
        uint256[] calldata _tokenIds
    ) external {
        require(
            hasRole(TOKEN_MARK_ROLE, msg.sender),
            "markERC721Token::Must have TOKEN_MARK_ROLE role to call method"
        );
        // limit to batches of 2000
        require(
            _tokenIds.length <= 2000,
            "markTokensAsSold::Attempted to mark more than 2000 tokens as sold"
        );

        // Mark provided tokens as sold.
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            markERC721Token(_originContract, _tokenIds[i], true);
        }
    }

    function markContractAsSold(address _contractAddress)
        external
        returns (bool)
    {
        require(
            hasRole(TOKEN_MARK_ROLE, msg.sender),
            "markContract::Must have TOKEN_MARK_ROLE role to call method"
        );
        return oldMarketplaceSettings.markContractAsSold(_contractAddress);
    }

    function getStakingFeePercentage() external view override returns (uint8) {
        return stakingFeePercentage;
    }

    function setStakingFeePercentage(uint8 _percentage) external onlyOwner {
        require(
            _percentage <= marketplaceFeePercentage,
            "setStakingFeePercentage::_percentage must be <= marketplaceFeePercentage"
        );
        stakingFeePercentage = _percentage;
    }

    function calculateStakingFee(uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        return (_amount * stakingFeePercentage) / 100;
    }

    function calculateMarketplacePayoutFee(uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        return
            (_amount * (marketplaceFeePercentage - stakingFeePercentage)) / 100;
    }
}
