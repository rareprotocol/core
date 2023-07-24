// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IBeaconUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol";
import {BeaconProxy} from "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";

import {IRewardAccumulatorFactory} from "./IRewardAccumulatorFactory.sol";
import {IRareStakingRegistry} from "../registry/IRareStakingRegistry.sol";
import {RewardAccumulator} from "../reward/RewardAccumulator.sol";

/// @author charlescrain
/// @title RewardAccumulatorFactory
/// @notice The RewardAccumulator Factory that creates RewardAccumulator contracts.
contract RewardAccumulatorFactory is IRewardAccumulatorFactory, IBeaconUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/

  address private rewardTemplate;

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/

  function initialize(
    address _rewardTemplate,
    address _newOwner
  ) external initializer {
    require(_rewardTemplate != address(0), "initialize::_rewardTemplate cannot be zero address");
    require(_newOwner != address(0), "initialize::_newOwner cannot be zero address");
    rewardTemplate = _rewardTemplate;
    __Ownable_init();
    __UUPSUpgradeable_init();
    _transferOwnership(_newOwner);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Internal UUPS Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address _implementation) internal override onlyOwner {
    require(_implementation != address(0), "_authorizeUpgrade::_implementation cannot be zero address");
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Admin Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRewardAccumulatorFactory
  /// @dev Requires the caller to be the owner of the contract.
  function setRewardSwapTemplate(address _rewardTemplate) external onlyOwner {
    require(_rewardTemplate != address(0), "setRewardSwapTemplate::_rewardTemplate cannot be zero address");
    rewardTemplate = _rewardTemplate;
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Deploys a RewardAccumulator contract.
  /// @param _stakingAddress Address of staking contract.
  /// @return address Address of the RewardAccumulator contract.
  function deployRewardSwap(address _stakingAddress) public returns (address payable) {
    require(_stakingAddress != address(0), "deployRewardSwap::_stakingAddress cannot be zero address");
    BeaconProxy newRewardSwap = new BeaconProxy(
      address(this),
      abi.encodeWithSelector(RewardAccumulator.initialize.selector, address(_stakingAddress))
    );

    emit RewardSwapContractCreated(address(newRewardSwap));
    return payable(address(newRewardSwap));
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRewardAccumulatorFactory
  function getRewardSwapTemplateAddress() external view returns (address) {
    return rewardTemplate;
  }

  /// @inheritdoc IBeaconUpgradeable
  function implementation() external view returns (address) {
    return rewardTemplate;
  }
}
