// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SuperRarePushSplitter is UUPSUpgradeable, OwnableUpgradeable {
    address[] public splitAddrs;
    uint256[] public splitRatios;

    // BIPs are done as 1000 = 10.00%
    function initiailize(
        address[] calldata _splitAddrs,
        uint256[] calldata _splitRatios
    ) external initializer {
        require(_splitAddrs.length == _splitRatios.length, "not same length");
        uint256 total = 0;

        for (uint256 i = 0; i < _splitRatios.length; i++) {
            total += _splitRatios[i];
        }

        require(total == 10000, "not enough ratios");

        splitAddrs = _splitAddrs;
        splitRatios = _splitRatios;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    receive() external payable {
        uint256 amt = msg.value;
        for (uint256 i = 0; i < splitAddrs.length; i++) {
            uint256 indAmt = (amt * splitRatios[i]) / 10000;
            (bool success, ) = splitAddrs[i].call{value: indAmt}("");
            require(success, "send not successful");
        }
    }
}
