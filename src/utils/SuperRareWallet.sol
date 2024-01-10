// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract SuperRareWallet is Ownable {
    function withdraw() external {
        address beneficiary = owner();
        uint256 balance = address(this).balance;
        (bool success, bytes memory returnData) = beneficiary.call{
            value: balance
        }("");
        require(success, string(returnData));
    }

    function migrateThisAsOwner(address _ownedAddress, address _newOwner)
        external
        onlyOwner
    {
        (bool success, bytes memory returnData) = address(_ownedAddress).call(
            abi.encodeWithSignature("transferOwnership(address)", _newOwner)
        );

        require(success, string(returnData));
    }

    receive() external payable {}
}
