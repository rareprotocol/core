// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author charlescrain
/// @title IRewardSwapFactory
/// @notice The RewardSwap Factory interface containing all functions, events, etc.
interface IRewardSwapFactory {
  /*//////////////////////////////////////////////////////////////////////////
                              Events
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted via {deployRewardSwap} when a new RewardSwap contract is deployed.
  event RewardSwapContractCreated(address indexed _stakingAddress);

  /*//////////////////////////////////////////////////////////////////////////
                          External Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Deploys a RewardSwap contract.
  /// @param _stakingAddress Address of staking contract.
  /// @return address Address of the RewardSwap contract.
  function deployRewardSwap(address _stakingAddress) external returns (address payable);

  /// @notice Set the staking registry address field to be used.
  /// @param _stakingRegistry Address of the new staking registry contract.
  function setStakingRegistry(address _stakingRegistry) external;

  /// @notice Set the RewardSwap template address to be used.
  /// @param _rewardSwapTemplate Address of the RewardSwap template.
  function setRewardSwapTemplate(address _rewardSwapTemplate) external;

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
