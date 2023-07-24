// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {IAccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IBeaconUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol";

import {BeaconProxy} from "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";

import {IRarityPoolFactory} from "./IRarityPoolFactory.sol";
import {IRewardAccumulatorFactory} from "./IRewardAccumulatorFactory.sol";
import {IRareStakingRegistry} from "../registry/IRareStakingRegistry.sol";
import {IRarityPool} from "../token/IRarityPool.sol";

/// @author koloz, charlescrain
/// @title RarityPoolFactory
/// @notice The Staking Factory Contract used to deploy new staking ERC20 contracts pertaining to a user.
/// @dev Made to be used with a UUPS Proxy.
contract RarityPoolFactory is IRarityPoolFactory, IBeaconUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/

  // Staking registry contract
  IRareStakingRegistry private stakingRegistry;

  // Reward swap factory contract
  IRewardAccumulatorFactory private rewardSwapFactory;

  // Template contract used for Beacon implementation
  address private rareStakingTemplate;

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/

  function initialize(
    address _stakingRegistry,
    address _rareStakingTemplate,
    address _rewardSwapFactory,
    address _newOwner
  ) external initializer {
    require(_stakingRegistry != address(0), "initialize::_stakingRegistry cannot be zero address");
    require(_rareStakingTemplate != address(0), "initialize::_rareStakingTemplate cannot be zero address");
    require(_rewardSwapFactory != address(0), "initialize::_rewardSwapFactory cannot be zero address");
    rewardSwapFactory = IRewardAccumulatorFactory(_rewardSwapFactory);
    rareStakingTemplate = _rareStakingTemplate;
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

  /// @inheritdoc IRarityPoolFactory
  /// @dev Requires the caller to be the owner of the contract.
  function setStakingRegistry(address _stakingRegistry) external onlyOwner {
    require(_stakingRegistry != address(0), "setStakingRegistry::_stakingRegistry cannot be zero address");
    stakingRegistry = IRareStakingRegistry(_stakingRegistry);
  }

  /// @inheritdoc IRarityPoolFactory
  /// @dev Requires the caller to be the owner of the contract.
  function setRareStakingTemplate(address _rareStakingTemplate) external onlyOwner {
    require(_rareStakingTemplate != address(0), "setRareStakingTemplate::_rareStakingTemplate cannot be zero address");
    rareStakingTemplate = _rareStakingTemplate;
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRarityPoolFactory
  /// @dev This contract must have the {STAKING_INFO_SETTER_ROLE} role on {RareStakingRegistry}.
  function deployStaking(address _user) public returns (address) {
    require(_user != address(0), "deployStaking::_user cannot be zero address");
    BeaconProxy newStaking = new BeaconProxy(
      address(this),
      abi.encodeWithSelector(
        IRarityPool.initialize.selector,
        _user,
        address(stakingRegistry),
        msg.sender
      )
    );
    address rewardSwap = rewardSwapFactory.deployRewardSwap(address(newStaking));
    stakingRegistry.setStakingAddresses(_user, address(newStaking), rewardSwap);

    bytes32 statSetterRole = stakingRegistry.STAKING_STAT_SETTER_ROLE();

    IAccessControlUpgradeable(address(stakingRegistry)).grantRole(statSetterRole, address(newStaking));

    emit IRarityPoolFactory.StakingContractCreated(msg.sender, _user, address(newStaking));

    return address(newStaking);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRarityPoolFactory
  function getStakingRegistryAddress() external view returns (address) {
    return address(stakingRegistry);
  }

  /// @inheritdoc IRarityPoolFactory
  function getRareStakingTemplateAddress() external view returns (address) {
    return rareStakingTemplate;
  }

  /// @inheritdoc IBeaconUpgradeable
  function implementation() external view returns (address) {
    return rareStakingTemplate;
  }
}
