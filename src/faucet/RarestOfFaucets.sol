// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";

contract RarestOfFaucets is Ownable {
    error ChillOut();
    error YUNoWork();
    error DontBeGreedy();

    mapping(address => uint256) private rareCooldowns;
    mapping(address => uint256) private ethCooldowns;

    uint256 private cooldownEth;
    uint256 private cooldownRare;

    uint256 private ethAmount;
    uint256 private rareAmount;

    address distributor;

    IERC20 private rare;

    constructor(address _rare, address _distributor) {
        rare = IERC20(_rare);
        cooldownEth = 1 days;
        cooldownRare = 1 days;
        ethAmount = 0.1 ether;
        rareAmount = 1000 ether;
        distributor = _distributor;
    }

    function setCooldownEth(uint256 _cooldown) external onlyOwner {
        cooldownEth = _cooldown;
    }

    function setCooldownRare(uint256 _cooldown) external onlyOwner {
        cooldownRare = _cooldown;
    }

    function setEthAmount(uint256 _amount) external onlyOwner {
        ethAmount = _amount;
    }

    function setRareAmount(uint256 _amount) external onlyOwner {
        rareAmount = _amount;
    }

    function setDistributor(address _distributor) external onlyOwner {
        distributor = _distributor;
    }

    function claimRare() external {
        if (rareCooldowns[msg.sender] > block.timestamp) revert ChillOut();
        rareCooldowns[msg.sender] = block.timestamp + cooldownRare;
        rare.transfer(msg.sender, rareAmount);
    }

    function claimEth() external {
        if (ethCooldowns[msg.sender] > block.timestamp) revert ChillOut();
        ethCooldowns[msg.sender] = block.timestamp + cooldownEth;
        (bool s, ) = msg.sender.call{value: ethAmount}("");
        if (!s) revert YUNoWork();
    }

    function withdrawAll() external {
        if (msg.sender != owner()) revert DontBeGreedy();
        (bool s, ) = msg.sender.call{value: address(this).balance}("");
        if (!s) revert YUNoWork();
        rare.transfer(msg.sender, rare.balanceOf(address(this)));
    }

    receive() external payable {}
}
