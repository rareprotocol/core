// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author charlescrain
/// @title IRewardAccumulatorFactory
/// @notice The RewardAccumulator Factory interface containing all functions, events, etc.
interface IRewardAccumulatorFactory {
  /*//////////////////////////////////////////////////////////////////////////
                              Events
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted via {deployRewardSwap} when a new RewardAccumulator contract is deployed.
  event RewardSwapContractCreated(address indexed _stakingAddress);

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Deploys a RewardAccumulator contract.
  /// @param _stakingAddress Address of staking contract.
  /// @return address Address of the RewardAccumulator contract.
  function deployRewardSwap(address _stakingAddress) external returns (address payable);

  /// @notice Set the staking registry address field to be used.
  /// @param _stakingRegistry Address of the new staking registry contract.
  function setStakingRegistry(address _stakingRegistry) external;

  /// @notice Set the RewardAccumulator template address to be used.
  /// @param _rewardTemplate Address of the RewardAccumulator template.
  function setRewardSwapTemplate(address _rewardTemplate) external;

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Retrieve the currently used staking registry address.
  /// @return address Address of the staking registry contract.
  function getStakingRegistryAddress() external view returns (address);

  /// @notice Retrieve the template contract
  /// @return address Address of the template.
  function getRewardSwapTemplateAddress() external view returns (address);
}
