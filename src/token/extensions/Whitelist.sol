// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Whitelist {
    uint256 constant MAX_UINT256 = type(uint256).max;

    mapping(address => uint256) public mintingAllowance;

    bool public whitelistEnabled = true;

    event MintingAllowanceUpdated(
        address indexed _address,
        uint256 _allowedAmount
    );

    modifier canMint(address _address, uint256 _numMints) {
        require(getMintingAllowance(_address) >= _numMints);
        _;
    }

    function _toggleWhitelist(bool _enabled) internal {
        whitelistEnabled = _enabled;
    }

    function _addToWhitelist(address _newAddress) internal {
        _changeMintingAllowance(_newAddress, MAX_UINT256);
        emit MintingAllowanceUpdated(_newAddress, MAX_UINT256);
    }

    function _removeFromWhitelist(address _newAddress) internal {
        _changeMintingAllowance(_newAddress, 0);
        emit MintingAllowanceUpdated(_newAddress, 0);
    }

    function _updateMintingAllowance(address _newAddress, uint256 _newAllowance)
        internal
    {
        _changeMintingAllowance(_newAddress, _newAllowance);
        emit MintingAllowanceUpdated(_newAddress, _newAllowance);
    }

    function getMintingAllowance(address _address)
        public
        view
        returns (uint256)
    {
        if (whitelistEnabled) {
            return mintingAllowance[_address];
        } else {
            return MAX_UINT256;
        }
    }

    function isWhitelisted(address _address) public view returns (bool) {
        return getMintingAllowance(_address) != 0 ? true : false;
    }

    function _decrementMintingAllowance(address _minter) internal {
        if (whitelistEnabled) {
            uint256 allowance = mintingAllowance[_minter];
            mintingAllowance[_minter] = allowance - 1;
        }
    }

    function _changeMintingAllowance(address _address, uint256 _allowance)
        internal
    {
        mintingAllowance[_address] = _allowance;
    }
}
