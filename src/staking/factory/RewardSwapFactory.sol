// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IBeaconUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol";
import {BeaconProxy} from "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";

import {IRewardSwapFactory} from "./IRewardSwapFactory.sol";
import {IRareStakingRegistry} from "../registry/IRareStakingRegistry.sol";
import {RewardSwap} from "../reward/RewardSwap.sol";

/// @author charlescrain
/// @title RewardSwapFactory
/// @notice The RewardSwap Factory that creates RewardSwap contracts.
contract RewardSwapFactory is IRewardSwapFactory, IBeaconUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/

  IRareStakingRegistry private stakingRegistry;

  address private rewardSwapTemplate;

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/

  function initialize(
    address _stakingRegistry,
    address _rewardSwapTemplate,
    address _newOwner
  ) external initializer {
    require(_stakingRegistry != address(0), "initialize::_stakingRegistry cannot be zero address");
    require(_rewardSwapTemplate != address(0), "initialize::_rewardSwapTemplate cannot be zero address");
    rewardSwapTemplate = _rewardSwapTemplate;
    stakingRegistry = IRareStakingRegistry(_stakingRegistry);
    __Ownable_init();
    _transferOwnership(_newOwner);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Internal UUPS Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address) internal override onlyOwner {}

  /*//////////////////////////////////////////////////////////////////////////
                          Admin Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRewardSwapFactory
  /// @dev Requires the caller to be the owner of the contract.
  function setStakingRegistry(address _stakingRegistry) external onlyOwner {
    require(_stakingRegistry != address(0), "setStakingRegistry::_stakingRegistry cannot be zero address");
    stakingRegistry = IRareStakingRegistry(_stakingRegistry);
  }

  /// @inheritdoc IRewardSwapFactory
  /// @dev Requires the caller to be the owner of the contract.
  function setRewardSwapTemplate(address _rewardSwapTemplate) external onlyOwner {
    require(_rewardSwapTemplate != address(0), "setRewardSwapTemplate::_rewardSwapTemplate cannot be zero address");
    rewardSwapTemplate = _rewardSwapTemplate;
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Deploys a RewardSwap contract.
  /// @param _stakingAddress Address of staking contract.
  /// @return address Address of the RewardSwap contract.
  function deployRewardSwap(address _stakingAddress) public returns (address payable) {
    require(_stakingAddress != address(0), "deployRewardSwap::_stakingAddress cannot be zero address");
    BeaconProxy newRewardSwap = new BeaconProxy(
      address(this),
      abi.encodeWithSelector(RewardSwap.initialize.selector, address(stakingRegistry), address(_stakingAddress))
    );

    emit RewardSwapContractCreated(address(newRewardSwap));
    return payable(address(newRewardSwap));
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRewardSwapFactory
  function getStakingRegistryAddress() external view returns (address) {
    return address(stakingRegistry);
  }

  /// @inheritdoc IRewardSwapFactory
  function getRewardSwapTemplateAddress() external view returns (address) {
    return rewardSwapTemplate;
  }

  /// @inheritdoc IBeaconUpgradeable
  function implementation() external view returns (address) {
    return rewardSwapTemplate;
  }
}
