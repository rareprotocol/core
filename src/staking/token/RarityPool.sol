// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {EnumerableMapUpgradeable} from "openzeppelin-contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import {EnumerableSetUpgradeable} from "openzeppelin-contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import {ERC20SnapshotUpgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import {ERC20BurnableUpgradeable, ERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";

import {IRarityPool} from "./IRarityPool.sol";
import {IRareStakingRegistry} from "../registry/IRareStakingRegistry.sol";

/// @author koloz, charlescrain
/// @title RarityPool
/// @notice The Staked ERC20 contract that allows users to stake/unstake/claim rewards/reward swaps.
/// @dev It is one base user per contract. This is the implementation contract for a beacon proxy.
contract RarityPool is IRarityPool, ERC20SnapshotUpgradeable, ReentrancyGuard {
  using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

  using Address for address payable;

  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/
  // Round # -> User -> HasClaimed
  mapping(uint256 => mapping(address => bool)) private stakerClaimedRound;

  // Round # -> Reward Amount
  mapping(uint256 => uint256) private roundRewardAmount;

  // Amount staked per user
  EnumerableMapUpgradeable.AddressToUintMap private amountStakedByUser;

  // Enumerable set of rounds that can be claimed
  EnumerableSetUpgradeable.UintSet private claimRounds;

  // The address of the target being staked on
  address private targetStakedTo;

  // Address of the RARE contract
  ERC20BurnableUpgradeable private rare;

  // Address of the staking registry
  IRareStakingRegistry private stakingRegistry;

  // Last round that had a snapshot, can be current round
  uint256 private lastRound;

  // Sum of all the rewards, only updated during snapshots
  uint256 private sumOfAllRewards;

  // Sum of the total amount claimed
  uint256 private sumOfAllClaimed;

  // Intial start for rounds
  uint256 private periodStart;

  // Last snapshot timestamp
  uint256 private lastSnapshotTimestamp;

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/
  function initialize(
    address _rare,
    address _userStakedTo,
    address _stakingRegistry,
    address _creator
  ) public initializer {
    __ERC20Snapshot_init();
    targetStakedTo = _userStakedTo;
    rare = ERC20BurnableUpgradeable(_rare);
    stakingRegistry = IRareStakingRegistry(_stakingRegistry);
    periodStart = block.timestamp;
    lastSnapshotTimestamp = 0;
    _mint(_creator, 1 ether);
    amountStakedByUser.set(_creator, 0);
    _snapshot(); // we do this increment the counter so rounds and snapshot IDs are equal.
    takeSnapshot();
  }

  function getStakingRegistry() public view returns (address) {
    return address(stakingRegistry);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Public Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  function addRewards(address _donor, uint256 _amount) public {
    if (_donor != msg.sender && msg.sender != stakingRegistry.getStakingInfoForUser(targetStakedTo).rewardAddress) {
      revert IRarityPool.Unauthorized();
    }

    // Cannot send 0 rewards
    if (_amount == 0) revert IRarityPool.CannotAddZeroRewards();

    takeSnapshot();

    // Get current round
    uint256 roundToUpdate = getCurrentRound();
    uint256 snapshotId = _getCurrentSnapshotId();

    // If there are no stakers, transfer the rewards to the default payee
    if (roundToUpdate > snapshotId && totalSupply() == 0) {
      stakingRegistry.transferRareTo(_donor, stakingRegistry.getDefaultPayee(), _amount);
      return;
    }

    // If there are no stakers, transfer the rewards to the default payee
    if (roundToUpdate == snapshotId && totalSupplyAt(roundToUpdate) == 0) {
      stakingRegistry.transferRareTo(_donor, stakingRegistry.getDefaultPayee(), _amount);
      return;
    }

    // Attribute rewards and any excess RARE stored in the contract
    // excess rare = Total RARE balance - RARE staked - unclaimed RARE aka (all rewards - claimed rewards)
    uint256 additionalRoundRewards = _amount +
      (rare.balanceOf(address(this)) -
        stakingRegistry.getTotalAmountStakedOnUser(targetStakedTo) -
        (sumOfAllRewards - sumOfAllClaimed));

    // Add new round reward.
    sumOfAllRewards += additionalRoundRewards;
    roundRewardAmount[roundToUpdate] += additionalRoundRewards;

    // Transfer the RARE in
    stakingRegistry.transferRareTo(_donor, address(this), _amount);

    // If this function has been called, then the round has RARE to claim
    if (!claimRounds.contains(roundToUpdate)) {
      claimRounds.add(roundToUpdate);
    }
    emit AddRewards(_donor, roundToUpdate, _amount, additionalRoundRewards, roundRewardAmount[roundToUpdate]);
  }

  /// @inheritdoc IRarityPool
  /// @dev Anyone can make this call.
  function takeSnapshot() public {
    // Snapshots can only occur if the period length has past.
    if (lastSnapshotTimestamp + stakingRegistry.getPeriodLength() <= block.timestamp) {
      uint256 oldsnapshotTimestamp = lastSnapshotTimestamp;
      lastSnapshotTimestamp = block.timestamp;
      _snapshot();
      emit StakingSnapshot(oldsnapshotTimestamp, lastSnapshotTimestamp, getCurrentRound());
    }
  }

  /// @inheritdoc IRarityPool
  /// @dev Caller must have given this contract allowance for their $RARE tokens.
  /// @dev On each call will check to see if the period needs to be updated.
  /// @dev Amount of synthetic token received is determined by a sqrt bonding curve.
  function stake(uint256 _amount) external nonReentrant {
    takeSnapshot();
    // Calculate SRARE to mint
    uint256 amountSRare = calculatePurchaseReturn(totalSupply(), _amount);

    // Move staked amount into pool
    stakingRegistry.transferRareTo(msg.sender, address(this), _amount);

    // Update amount staked by user on pool and on registry
    (, uint256 amtStaked) = amountStakedByUser.tryGet(msg.sender);
    amountStakedByUser.set(msg.sender, amtStaked + _amount);
    stakingRegistry.increaseAmountStaked(msg.sender, targetStakedTo, _amount);

    // Mint new SRARE to staker
    _mint(msg.sender, amountSRare);
    emit Stake(msg.sender, _amount, amtStaked + _amount, amountSRare);
  }

  /// @inheritdoc IRarityPool
  /// @dev On each call will check to see if the period needs to be updated.
  /// @dev Amount of $RARE received is the % of your synthetic tokens unstaked.
  /// @dev {deflationaryPercentage} of the unstaked rare is burned.
  function unstake(uint256 _amount) external nonReentrant {
    takeSnapshot();

    // Check SRARE balance of sender
    uint256 srareBalance = balanceOf(msg.sender);
    if (_amount > srareBalance) {
      revert InsufficientSyntheticRare();
    }

    // Calculate and check amount of staked RARE to return
    (, uint256 amtStaked) = amountStakedByUser.tryGet(msg.sender);
    uint256 amountRareReturned = calculateSaleReturn(balanceOf(msg.sender), amtStaked, _amount);
    if (amountRareReturned > amtStaked) {
      revert InsufficientStakedRare();
    }

    // Clean up staked amount on pool and on registry
    amtStaked - amountRareReturned == 0
      ? amountStakedByUser.remove(msg.sender)
      : amountStakedByUser.set(msg.sender, amtStaked - amountRareReturned);
    stakingRegistry.decreaseAmountStaked(msg.sender, targetStakedTo, amountRareReturned);

    // Burn SRARE
    _burn(msg.sender, _amount);

    // Perform burn of RARE
    uint256 burnAmount = (amountRareReturned * stakingRegistry.getDeflationaryPercentage()) / 100_00;
    rare.burn(burnAmount);

    // Return staked RARE
    uint256 amountDue = amountRareReturned - burnAmount;
    rare.transfer(msg.sender, amountDue);

    emit Unstake(msg.sender, amountRareReturned, amtStaked - amountRareReturned, burnAmount, _amount);
  }

  /// @inheritdoc IRarityPool
  /// @dev Will snapshot a new round if possible.
  function claimRewardsForRounds(address _user, uint256[] memory _rounds) external nonReentrant {
    takeSnapshot();
    if (_rounds.length == 0) revert IRarityPool.ClaimingZeroRounds();
    if (_rounds.length > 255) revert IRarityPool.ClaimingTooManyRounds();

    // Build total rewards for claim
    uint256 rewards = 0;
    uint256 currentRound = getCurrentRound();
    uint256 currentSnapshotId = _getCurrentSnapshotId();
    for (uint8 i = 0; i < _rounds.length; i++) {
      if (_rounds[i] == currentRound) revert IRarityPool.CannotClaimCurrentRound();
      if (stakerClaimedRound[_rounds[i]][_user]) revert IRarityPool.RewardAlreadyClaimed();
      rewards += _getRewardsForUserForRound(_user, _rounds[i], currentRound, currentSnapshotId);
      stakerClaimedRound[_rounds[i]][_user] = true;
    }

    // Build percentage breakdowns for all who have claim on the claims
    uint256 owedToStakee = (rewards * stakingRegistry.getStakeePercentage(targetStakedTo)) / 100_00;
    uint256 owedToClaimer = (rewards * stakingRegistry.getClaimerPercentage(_user)) / 100_00;
    uint256 owedToStaker = rewards - owedToStakee - owedToClaimer;

    // Transfer rewards
    rare.transfer(msg.sender, owedToClaimer);
    rare.transfer(_user, owedToStaker);
    rare.transfer(targetStakedTo, owedToStakee);

    // Update total claim amounts
    sumOfAllClaimed += rewards;
    emit RewardClaimed(msg.sender, _user, owedToStaker, owedToClaimer, owedToStakee);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External/Public Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRarityPool
  function stakerHasClaimedForRound(address _staker, uint256 _round) external view returns (bool) {
    return stakerClaimedRound[_round][_staker];
  }

  /// @inheritdoc IRarityPool
  function getAmountStakedByUser(address _user) external view returns (uint256) {
    (, uint256 amtStaked) = amountStakedByUser.tryGet(_user);
    return amtStaked;
  }

  /// @inheritdoc IRarityPool
  function name() public view override(IRarityPool, ERC20Upgradeable) returns (string memory) {
    IRareStakingRegistry.Info memory info = stakingRegistry.getStakingInfoForUser(targetStakedTo);
    return info.name;
  }

  /// @inheritdoc IRarityPool
  function symbol() public view override(IRarityPool, ERC20Upgradeable) returns (string memory) {
    IRareStakingRegistry.Info memory info = stakingRegistry.getStakingInfoForUser(targetStakedTo);
    return info.symbol;
  }

  /// @inheritdoc IRarityPool
  function getTargetBeingStakedOn() external view returns (address) {
    return targetStakedTo;
  }

  /// @inheritdoc IRarityPool
  function getAllStakers() external view returns (address[] memory) {
    uint256 length = amountStakedByUser.length();

    address[] memory stakers = new address[](length);

    for (uint256 i = 0; i < length; i++) {
      (address staker, ) = amountStakedByUser.at(i);
      stakers[i] = staker;
    }

    return stakers;
  }

  /// @inheritdoc IRarityPool
  function getRoundRewards(uint256 _round) public view returns (uint256) {
    return roundRewardAmount[_round];
  }

  /// @inheritdoc IRarityPool
  function getHistoricalRewardsForUserForRounds(address _user, uint256[] memory _rounds)
    external
    view
    returns (uint256)
  {
    uint256 rewards = 0;
    uint256 currentRound = getCurrentRound();
    uint256 currentSnapshotId = _getCurrentSnapshotId();
    for (uint8 i = 0; i < _rounds.length; i++) {
      rewards += _getRewardsForUserForRound(_user, _rounds[i], currentRound, currentSnapshotId);
    }
    return rewards;
  }

  /// @inheritdoc IRarityPool
  function getClaimableRewardsForUserForRounds(address _user, uint256[] memory _rounds) public view returns (uint256) {
    uint256 rewards = 0;
    uint256 currentRound = getCurrentRound();
    uint256 currentSnapshotId = _getCurrentSnapshotId();
    for (uint8 i = 0; i < _rounds.length; i++) {
      if (_rounds[i] == currentRound) revert IRarityPool.CannotClaimCurrentRound();
      if (stakerClaimedRound[_rounds[i]][_user]) revert IRarityPool.RewardAlreadyClaimed();
      rewards += _getRewardsForUserForRound(_user, _rounds[i], currentRound, currentSnapshotId);
    }
    return rewards;
  }

  /// @inheritdoc IRarityPool
  function getCurrentRound() public view returns (uint256) {
    if (block.timestamp < lastSnapshotTimestamp + stakingRegistry.getPeriodLength()) {
      return _getCurrentSnapshotId();
    }
    return _getCurrentSnapshotId() + 1;
  }

  /// @inheritdoc IRarityPool
  /// @dev Calculated based on a sqrt token bonding curve.
  function calculatePurchaseReturn(uint256 _totalSRare, uint256 _stakedAmount) public pure returns (uint256) {
    //
    return (((_sqrt(2e28 * _stakedAmount + _totalSRare**2) - _totalSRare) * _sqrt(_stakedAmount)) / 1e13); // We multiply by a factor of 1e5 to floor out decimals for last 5 digits
  }

  /// @inheritdoc IRarityPool
  /// @dev Calculated based on percentage sRARE being unstaked.
  function calculateSaleReturn(
    uint256 _totalSRareByUser,
    uint256 _totalRareStakedByUser,
    uint256 _unstakeAmount
  ) public pure returns (uint256) {
    return ((_unstakeAmount * 100 * _totalRareStakedByUser) / _totalSRareByUser) / 100;
  }

  /// @inheritdoc IRarityPool
  function getAllTimeRewards() external view returns (uint256) {
    return sumOfAllRewards;
  }

  /// @inheritdoc IRarityPool
  function getClaimRounds() external view returns (uint256[] memory) {
    return claimRounds.values();
  }

  /// @inheritdoc IRarityPool
  function getCreationTime() external view returns (uint256) {
    return periodStart;
  }

  /// IRarityPool
  function getLastSnapshotTimestamp() external view returns (uint256) {
    return lastSnapshotTimestamp;
  }

  /// IRarityPool
  function getSumOfAllClaimed() external view returns (uint256) {
    return sumOfAllClaimed;
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Internal Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @dev Transfer function for moving synthetic tokens.
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    if (msg.sender != address(this)) revert IRarityPool.Unauthorized();
    super._transfer(from, to, amount);
  }

  /// @dev Query rewards for this user this round.
  /// @param _user Address of the user to get rewards.
  /// @return uint256 Amount of $RARE tokens rewarded this round.
  function _getRewardsForUserForRound(
    address _user,
    uint256 _round,
    uint256 _currentRound,
    uint256 _currentSnapshotId
  ) internal view returns (uint256) {
    // If asking for a future round, there can be no rewards
    if (_round > _currentRound) return 0;

    // If current round is greater that the snapshot ID, there is no snapshot to use so grab current
    uint256 totalSRareSupply = _currentRound > _currentSnapshotId ? totalSupply() : totalSupplyAt(_round);

    // If there is no SRARE supply, return 0
    if (totalSRareSupply == 0) return 0;

    // If current round is greater that the snapshot ID, there is no snapshot to use so grab current
    uint256 senderBalance = _currentRound > _currentSnapshotId ? balanceOf(_user) : balanceOfAt(_user, _round);

    // Here we multiply by 1e25 to pad zeroes for division
    return ((senderBalance * 1e25 * getRoundRewards(_round)) / totalSRareSupply) / 1e25;
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Internal Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @dev based on https://github.com/Gaussian-Process/solidity-sqrt/blob/main/src/FixedPointMathLib.sol
  function _sqrt(uint256 x) internal pure returns (uint256 z) {
    assembly {
      // This segment is to get a reasonable initial estimate for the Babylonian method.
      // If the initial estimate is bad, the number of correct bits increases ~linearly
      // each iteration instead of ~quadratically.
      // The idea is to get z*z*y within a small factor of x.
      // More iterations here gets y in a tighter range. Currently, we will have
      // y in [256, 256*2^16). We ensure y>= 256 so that the relative difference
      // between y and y+1 is small. If x < 256 this is not possible, but those cases
      // are easy enough to verify exhaustively.
      z := 181 // The 'correct' value is 1, but this saves a multiply later
      let y := x
      // Note that we check y>= 2^(k + 8) but shift right by k bits each branch,
      // this is to ensure that if x >= 256, then y >= 256.
      if iszero(lt(y, 0x10000000000000000000000000000000000)) {
        y := shr(128, y)
        z := shl(64, z)
      }
      if iszero(lt(y, 0x1000000000000000000)) {
        y := shr(64, y)
        z := shl(32, z)
      }
      if iszero(lt(y, 0x10000000000)) {
        y := shr(32, y)
        z := shl(16, z)
      }
      if iszero(lt(y, 0x1000000)) {
        y := shr(16, y)
        z := shl(8, z)
      }
      // Now, z*z*y <= x < z*z*(y+1), and y <= 2^(16+8),
      // and either y >= 256, or x < 256.
      // Correctness can be checked exhaustively for x < 256, so we assume y >= 256.
      // Then z*sqrt(y) is within sqrt(257)/sqrt(256) of x, or about 20bps.

      // The estimate sqrt(x) = (181/1024) * (x+1) is off by a factor of ~2.83 both when x=1
      // and when x = 256 or 1/256. In the worst case, this needs seven Babylonian iterations.
      z := shr(18, mul(z, add(y, 65536))) // A multiply is saved from the initial z := 181

      // Run the Babylonian method seven times. This should be enough given initial estimate.
      // Possibly with a quadratic/cubic polynomial above we could get 4-6.
      z := shr(1, add(z, div(x, z)))
      z := shr(1, add(z, div(x, z)))
      z := shr(1, add(z, div(x, z)))
      z := shr(1, add(z, div(x, z)))
      z := shr(1, add(z, div(x, z)))
      z := shr(1, add(z, div(x, z)))
      z := shr(1, add(z, div(x, z)))

      // See https://en.wikipedia.org/wiki/Integer_square_root#Using_only_integer_division.
      // If x+1 is a perfect square, the Babylonian method cycles between
      // floor(sqrt(x)) and ceil(sqrt(x)). This check ensures we return floor.
      // The solmate implementation assigns zRoundDown := div(x, z) first, but
      // since this case is rare, we choose to save gas on the assignment and
      // repeat division in the rare case.
      // If you don't care whether floor or ceil is returned, you can skip this.
      if lt(div(x, z), z) {
        z := div(x, z)
      }
    }
  }
}
