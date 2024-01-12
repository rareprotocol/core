// contracts/royalty/ERC2981.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "openzeppelin-contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./IERC2981.sol";

abstract contract ERC2981Upgradeable is IERC2981, ERC165Upgradeable {
    using SafeMathUpgradeable for uint256;

    // bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    address private defaultRoyaltyReceiver;

    uint256 private defaultRoyaltyPercentage;

    mapping(uint256 => address) royaltyReceivers;
    mapping(uint256 => uint256) royaltyPercentages;

    constructor() {}

    function __ERC2981__init() internal onlyInitializing {
        __ERC165_init();
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        public
        view
        virtual
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = royaltyReceivers[_tokenId] != address(0)
            ? royaltyReceivers[_tokenId]
            : defaultRoyaltyReceiver;
        royaltyAmount = _salePrice
            .mul(
                royaltyPercentages[_tokenId] != 0
                    ? royaltyPercentages[_tokenId]
                    : defaultRoyaltyPercentage
            )
            .div(100);
    }

    function _setDefaultRoyaltyReceiver(address _receiver) internal {
        defaultRoyaltyReceiver = _receiver;
    }

    function _setRoyaltyReceiver(uint256 _tokenId, address _newReceiver)
        internal
    {
        royaltyReceivers[_tokenId] = _newReceiver;
    }

    function _setRoyaltyPercentage(uint256 _tokenId, uint256 _percentage)
        internal
    {
        royaltyPercentages[_tokenId] = _percentage;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function _setDefaultRoyaltyPercentage(uint256 _percentage) internal {
        defaultRoyaltyPercentage = _percentage;
    }

    function getDefaultRoyaltyReceiver() public view returns (address) {
        return defaultRoyaltyReceiver;
    }

    function getDefaultRoyaltyPercentage() public view returns (uint256) {
        return defaultRoyaltyPercentage;
    }
}
