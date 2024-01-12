// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITokenCreator} from "./ITokenCreator.sol";

abstract contract TokenCreator is ITokenCreator {
    mapping(uint256 => address) private _tokenCreators;

    // bytes4(keccak256(tokenCreator(uint256))) == 0x40c1a064
    function tokenCreator(uint256 _tokenId)
        public
        view
        returns (address payable)
    {
        return payable(_tokenCreators[_tokenId]);
    }

    function _setTokenCreator(uint256 _tokenId, address _creator) internal {
        _tokenCreators[_tokenId] = _creator;
    }
}
