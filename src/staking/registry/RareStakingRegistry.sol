// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {AccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EnumerableMapUpgradeable} from "openzeppelin-contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import {EnumerableSetUpgradeable} from "openzeppelin-contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IBeaconUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";
import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {strings} from "arachnid/solidity-stringutils/src/strings.sol";
import "@ensdomains/ens-contracts/registry/ReverseRegistrar.sol";
import "@ensdomains/ens-contracts/resolvers/profiles/INameResolver.sol";
import "@uniswap/v3-core/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/libraries/OracleLibrary.sol";

import {IRarityPool} from "../token/IRarityPool.sol";

import {IRareStakingRegistry} from "./IRareStakingRegistry.sol";

/// @author koloz, charlescrain
/// @title RareStakingRegistry
/// @notice The Staking Registry contract that holds info such as the staking contract for a given user and global staking stats.
/// @dev Made to be used with a UUPS Proxy.
contract RareStakingRegistry is IRareStakingRegistry, AccessControlUpgradeable, UUPSUpgradeable {
  // ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣤⣶⣶⣦⣤⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣾⠟⠋⠁⠀⠀⠀⠀⠀⠙⠻⣷⣄⠀⠀⠀⠀⠀⠀
  // ⠀⠀⠀⠀⠀⠀⠀⢀⣴⠟⢻⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠙⢷⡄⠀⠀⠀⠀
  // ⠀⠀⠀⠀⠀⠀⣠⡞⠁⠀⢸⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⣿⠀⣄⠀⠀
  // ⠀⠀⠀⠀⠀⣴⠋⠀⠀⠀⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣼⡟⢠⣿⡆⠀
  // ⠀⠀⠀⢀⣾⣧⣤⠤⠶⠾⣿⣦⣄⣀⠀⠀⠀⠀⠀⠀⣀⣠⡴⠞⠋⣠⣿⠟⠀⠀
  // ⠀⠀⠀⣼⠟⠁⠀⠀⠀⠀⠀⠈⠙⠻⢿⣿⣿⣿⠿⠛⠋⣁⣤⣶⡿⠟⠁⠀⠀⠀
  // ⠀⠀⣼⡇⠀⠀⠀⠀⠀⠀⠀⠀⣠⡾⠟⢉⣁⣤⣶⠾⠟⠋⠉⠀⠀⠀⠀⠀⠀⠀
  // ⠀⢠⣿⠀⢠⣾⣿⡆⠀⠀⣠⡾⠋⣠⣴⡿⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⢸⣿⠀⠘⠛⠛⠁⣠⣾⠏⢀⣾⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⠈⣿⡄⠀⠀⣠⣾⠟⢁⣴⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⠀⠈⠻⠿⠿⠛⢁⣴⡿⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⠀⠀⠀⠀⠀⠚⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
  // ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀

  using strings for *;
  using SafeCast for uint256;
  using SafeCast for uint128;
  using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

  /*//////////////////////////////////////////////////////////////////////////
                              Constants
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRareStakingRegistry
  bytes32 public constant STAKING_INFO_SETTER_ROLE = keccak256("STAKING_INFO_SETTER_ROLE");

  /// @inheritdoc IRareStakingRegistry
  bytes32 public constant STAKING_STAT_SETTER_ADMIN_ROLE = keccak256("STAKING_STAT_SETTER_ADMIN_ROLE");

  /// @inheritdoc IRareStakingRegistry
  bytes32 public constant STAKING_STAT_SETTER_ROLE = keccak256("STAKING_STAT_SETTER_ROLE");

  /// @inheritdoc IRareStakingRegistry
  bytes32 public constant STAKING_CONFIG_SETTER_ROLE = keccak256("STAKING_CONFIG_SETTER_ROLE");

  /// @inheritdoc IRareStakingRegistry
  bytes32 public constant ENS_SETTER_ROLE = keccak256("ENS_SETTER_ROLE");

  /// @inheritdoc IRareStakingRegistry
  bytes32 public constant SWAP_POOL_SETTER_ROLE = keccak256("SWAP_POOL_SETTER_ROLE");

  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/

  // Mapping of address to the User's staking info.
  mapping(address => Info) private userToStakingInfo;

  // Mapping of ERC20 token address to the ETH/ERC20 Uniswap pool.
  mapping(address => address) private swapPools;

  // Mapping of user address to the percentage of rewards they want to give to the claimer.
  mapping(address => uint256) private claimerRewardByStaker;

  // Mapping of user address to the percentage of rewards to go to target being staked on.
  mapping(address => uint256) private stakeeRewards;

  // Enumerable set of staking contracts.
  EnumerableSetUpgradeable.AddressSet private stakingContracts;

  // Enumerable map of total RARE staked by a user.
  EnumerableMapUpgradeable.AddressToUintMap private amountStakedByUser;

  // Enumerable map of total RARE staked by on a target.
  EnumerableMapUpgradeable.AddressToUintMap private amountStakedOnTarget;

  // ENS reverse registrar
  ReverseRegistrar private reverseRegistrar;

  // ENS name resolver
  INameResolver private resolver;

  // Round period length for all staking contracts to use.
  uint256 private periodLength;

  // Percent to burn on unstake .
  uint256 private deflationaryPercentage;

  // Address of RARE ERC20 token contract.
  address private rare;

  // Address of WETH ERC20 token contract.
  address private weth;

  // Percentage of price pair to RARE for Reward Swapping.
  uint256 private discountedPercent;

  // Address of the default payee.
  address private defaultPayee;

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/
  function initialize(
    address _owner,
    address _reverseRegistrar,
    address _resolver,
    uint256 _periodLength,
    uint256 _deflationaryPercentage,
    uint256 _discountedPercent,
    address _rare,
    address _weth,
    address _defaultPayee
  ) external initializer {
    if (_periodLength > 365 days) revert PeriodLengthBeyondLimit();
    if (_deflationaryPercentage > 100_00) revert PercentageBeyondLimit();
    if (_discountedPercent > 100_00) revert PercentageBeyondLimit();
    if (_owner == address(0)) revert ZeroAddressUnsupported();
    if (_reverseRegistrar == address(0)) revert ZeroAddressUnsupported();
    if (_resolver == address(0)) revert ZeroAddressUnsupported();
    if (_rare == address(0)) revert ZeroAddressUnsupported();
    if (_weth == address(0)) revert ZeroAddressUnsupported();
    if (_defaultPayee == address(0)) revert ZeroAddressUnsupported();
    _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    _setRoleAdmin(STAKING_STAT_SETTER_ROLE, STAKING_STAT_SETTER_ADMIN_ROLE);
    reverseRegistrar = ReverseRegistrar(_reverseRegistrar);
    resolver = INameResolver(_resolver);
    deflationaryPercentage = _deflationaryPercentage;
    periodLength = _periodLength;
    rare = _rare;
    weth = _weth;
    discountedPercent = _discountedPercent;
    defaultPayee = _defaultPayee;
    __AccessControl_init();
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Internal UUPS Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc UUPSUpgradeable
  function _authorizeUpgrade(address) internal view override {
    if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Unauthorized();
  }

  /*//////////////////////////////////////////////////////////////////////////
                            Admin Write Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @dev Requires the caller to have the {STAKING_INFO_SETTER_ROLE} access control role.
  function setStakingAddresses(
    address _user,
    address _stakingAddress,
    address _rewardSwapAddress
  ) external {
    if (!hasRole(STAKING_INFO_SETTER_ROLE, msg.sender)) revert Unauthorized();
    if (userToStakingInfo[_user].stakingAddress != address(0)) revert StakingContractAlreadyExists();
    userToStakingInfo[_user] = Info("", "", _stakingAddress, _rewardSwapAddress);
    stakingContracts.add(_stakingAddress);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {STAKING_STAT_SETTER_ROLE} access control role.
  function increaseAmountStaked(
    address _staker,
    address _stakedOn,
    uint256 _amount
  ) external {
    if (!hasRole(STAKING_STAT_SETTER_ROLE, msg.sender)) revert Unauthorized();
    (, uint256 amtStaked) = amountStakedByUser.tryGet(_staker);
    amountStakedByUser.set(_staker, amtStaked + _amount);

    (, uint256 amtStakedOn) = amountStakedOnTarget.tryGet(_stakedOn);
    amountStakedOnTarget.set(_stakedOn, amtStakedOn + _amount);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {STAKING_STAT_SETTER_ROLE} access control role.
  function decreaseAmountStaked(
    address _staker,
    address _stakedOn,
    uint256 _amount
  ) external {
    if (!hasRole(STAKING_STAT_SETTER_ROLE, msg.sender)) revert Unauthorized();
    (, uint256 amtStaked) = amountStakedByUser.tryGet(_staker);

    if (amtStaked - _amount == 0) {
      amountStakedByUser.remove(_staker);
    } else {
      amountStakedByUser.set(_staker, amtStaked - _amount);
    }

    (, uint256 amtStakedOn) = amountStakedOnTarget.tryGet(_stakedOn);

    if (amtStakedOn - _amount == 0) {
      amountStakedOnTarget.remove(_stakedOn);
    } else {
      amountStakedOnTarget.set(_stakedOn, amtStakedOn - _amount);
    }
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {STAKING_CONFIG_SETTER_ROLE} access control role.
  function setDefaultPayee(address _payee) external {
    if (_payee == address(0)) revert ZeroAddressUnsupported();
    if (!hasRole(STAKING_CONFIG_SETTER_ROLE, msg.sender)) revert Unauthorized();
    defaultPayee = _payee;
    emit DefaultPayeeUpdated(_payee);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {STAKING_CONFIG_SETTER_ROLE} access control role.
  function setDeflationaryPercentage(uint256 _percentage) external {
    if (_percentage > 100_00) revert PercentageBeyondLimit();
    if (!hasRole(STAKING_CONFIG_SETTER_ROLE, msg.sender)) revert Unauthorized();
    deflationaryPercentage = _percentage;
    emit DeflationaryPercentageUpdated(_percentage);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {STAKING_CONFIG_SETTER_ROLE} access control role.
  function setDiscountPercentage(uint256 _percentage) external {
    if (_percentage > 100_00) revert PercentageBeyondLimit();
    if (!hasRole(STAKING_CONFIG_SETTER_ROLE, msg.sender)) revert Unauthorized();
    discountedPercent = _percentage;
    emit DiscountPercentageUpdated(_percentage);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {STAKING_CONFIG_SETTER_ROLE} access control role.
  function setPeriodLength(uint256 _periodLength) external {
    if (_periodLength > 365 days) revert PeriodLengthBeyondLimit();
    if (!hasRole(STAKING_CONFIG_SETTER_ROLE, msg.sender)) revert Unauthorized();
    periodLength = _periodLength;
    emit PeriodLengthUpdated(_periodLength);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {ENS_SETTER_ROLE} access control role.
  function setReverseRegistrar(address _reverseRegistrar) external {
    if (_reverseRegistrar == address(0)) revert ZeroAddressUnsupported();
    if (!hasRole(ENS_SETTER_ROLE, msg.sender)) revert Unauthorized();
    reverseRegistrar = ReverseRegistrar(_reverseRegistrar);
    emit ReverseRegistrarUpdated(_reverseRegistrar);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {ENS_SETTER_ROLE} access control role.
  function setResolver(address _resolver) external {
    if (_resolver == address(0)) revert ZeroAddressUnsupported();
    if (!hasRole(ENS_SETTER_ROLE, msg.sender)) revert Unauthorized();
    resolver = INameResolver(_resolver);
    emit ResolverUpdated(_resolver);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {SWAP_POOL_SETTER_ROLE} of the contract.
  function setSwapPool(address _uniswapPool, address _token) external {
    if (IUniswapV3Pool(_uniswapPool).token0() != _token || IUniswapV3Pool(_uniswapPool).token1() != weth) {
      revert InvalidPool();
    }
    if (!hasRole(SWAP_POOL_SETTER_ROLE, msg.sender)) {
      revert Unauthorized();
    }
    swapPools[_token] = _uniswapPool;
    emit SetSwapPool(_uniswapPool, _token);
  }

  /// @inheritdoc IRareStakingRegistry
  function setStakeePercentage(uint256 _stakeePercentage) external {
    if (_stakeePercentage > 50_00) revert PercentageBeyondLimit();
    stakeeRewards[msg.sender] = _stakeePercentage;
    emit StakeePercentageUpdated(msg.sender, _stakeePercentage);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Requires the caller to have the {SET_CLAIMER_PERCENTAGE_ROLE} of the contract.
  function setClaimerPercentage(uint256 _claimerPercentage) external {
    if (_claimerPercentage > 50_00) revert PercentageBeyondLimit();
    claimerRewardByStaker[msg.sender] = _claimerPercentage;
    emit ClaimerPercentageUpdated(msg.sender, _claimerPercentage);
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Only staking pool contracts can call this.
  function transferRareTo(
    address _from,
    address _to,
    uint256 _amount
  ) external {
    if (IERC20Upgradeable(rare).allowance(_from, address(this)) < _amount) {
      revert InsufficientRareAllowance();
    }
    if (!stakingContracts.contains(msg.sender)) revert Unauthorized();
    SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(rare), _from, _to, _amount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IRareStakingRegistry
  function getDiscountPercentage() external view returns (uint256) {
    return discountedPercent;
  }

  /// @inheritdoc IRareStakingRegistry
  function getDefaultPayee() external view returns (address) {
    return defaultPayee;
  }

  /// @inheritdoc IRareStakingRegistry
  function getSwapPool(address _token) external view returns (address) {
    return swapPools[_token];
  }

  /// @inheritdoc IRareStakingRegistry
  function getWethAddress() external view returns (address) {
    return weth;
  }

  /// @inheritdoc IRareStakingRegistry
  function getRareAddress() external view returns (address) {
    return rare;
  }

  /// @inheritdoc IRareStakingRegistry
  function getDeflationaryPercentage() external view returns (uint256) {
    return deflationaryPercentage;
  }

  /// @inheritdoc IRareStakingRegistry
  function getPeriodLength() external view returns (uint256) {
    return periodLength;
  }

  /// @inheritdoc IRareStakingRegistry
  function getStakingInfoForUser(address _user) external view returns (Info memory) {
    Info memory info = userToStakingInfo[_user];
    strings.slice memory name = resolver.name((reverseRegistrar.node(_user))).toSlice();
    if (name.len() != 0) {
      name.rsplit(".".toSlice());
      info.name = ("Synthetic RARE | ".toSlice()).concat(name);
      info.symbol = ("xRARE_".toSlice()).concat(upper(name.toString()).toSlice());
      return info;
    }
    string memory userStr = Strings.toHexString(_user);
    strings.slice memory beginning = _substring(userStr, 6, 0).toSlice();
    strings.slice memory end = _substring(userStr, 4, 35).toSlice();
    strings.slice memory stakingNumber = beginning.concat(end).toSlice();
    info.name = ("Synthetic RARE | ".toSlice()).concat(stakingNumber);
    info.symbol = ("xRARE_".toSlice()).concat(stakingNumber);
    return info;
  }

  /// @inheritdoc IRareStakingRegistry
  function getStakeePercentage(address _user) external view returns (uint256 amount) {
    return stakeeRewards[_user];
  }

  /// @inheritdoc IRareStakingRegistry
  function getTotalAmountStakedByUser(address _user) external view returns (uint256 amount) {
    (, amount) = amountStakedByUser.tryGet(_user);
  }

  /// @inheritdoc IRareStakingRegistry
  function getTotalAmountStakedOnUser(address _user) external view returns (uint256 amount) {
    (, amount) = amountStakedOnTarget.tryGet(_user);
  }

  /// @inheritdoc IRareStakingRegistry
  function getAllStakingContracts() external view returns (address[] memory) {
    return stakingContracts.values();
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev This function is intended to be called off chain.
  function getAllStakers() external view returns (address[] memory) {
    uint256 length = amountStakedByUser.length();

    address[] memory stakers = new address[](length);

    for (uint256 i = 0; i < length; i++) {
      (address staker, ) = amountStakedByUser.at(i);
      stakers[i] = staker;
    }

    return stakers;
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev This function is intended to be called off chain.
  function getAllStakedOn() external view returns (address[] memory) {
    uint256 length = amountStakedOnTarget.length();

    address[] memory stakedOn = new address[](length);

    for (uint256 i = 0; i < length; i++) {
      (address staker, ) = amountStakedOnTarget.at(i);
      stakedOn[i] = staker;
    }

    return stakedOn;
  }

  /// @inheritdoc IRareStakingRegistry
  /// @dev Order maintained and zero address returned if it doesnt exist.
  /// @dev This function is intended to be called off chain.
  function getUsersForStakingAddresses(address[] calldata _stakingAddrs) external view returns (address[] memory) {
    address[] memory users = new address[](_stakingAddrs.length);

    for (uint256 i = 0; i < _stakingAddrs.length; i++) {
      try IRarityPool(_stakingAddrs[i]).getTargetBeingStakedOn() returns (address user) {
        users[i] = user;
      } catch {
        users[i] = address(0);
      }
    }

    return users;
  }

  /// @inheritdoc IRareStakingRegistry
  function getClaimerPercentage(address _user) external view returns (uint256) {
    return claimerRewardByStaker[_user];
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Internal Read Functions
  //////////////////////////////////////////////////////////////////////////*/

  /// @notice Converts all the values of a string to their corresponding upper case value. Taken from: https://github.com/willitscale/solidity-util
  /// @param _base When being used for a data type this is the extended object otherwise this is the string base to convert to upper case
  /// @return string
  function upper(string memory _base) internal pure returns (string memory) {
    bytes memory _baseBytes = bytes(_base);
    for (uint256 i = 0; i < _baseBytes.length; i++) {
      _baseBytes[i] = _upper(_baseBytes[i]);
    }
    return string(_baseBytes);
  }

  /// @notice Convert an alphabetic character to upper case and return the original value when not alphabetic. Taken from: https://github.com/willitscale/solidity-util
  /// @param _b1 The byte to be converted to upper case
  /// @return bytes1 The converted value if the passed value was alphabetic and in a lower case otherwise returns the original value
  function _upper(bytes1 _b1) private pure returns (bytes1) {
    if (_b1 >= 0x61 && _b1 <= 0x7A) {
      return bytes1(uint8(_b1) - 32);
    }

    return _b1;
  }

  /// @notice Extracts the part of a string based on the desired length and offset. The offset and length must not exceed the lenth of the base string. Taken from: https://github.com/willitscale/solidity-util
  /// @param _base When being used for a data type this is the extended object otherwise this is the string that will be used for extracting the sub string from
  /// @param _length The length of the sub string to be extracted from the base
  /// @param _offset The starting point to extract the sub string from
  /// @return string The extracted sub string
  function _substring(
    string memory _base,
    int256 _length,
    int256 _offset
  ) internal pure returns (string memory) {
    bytes memory _baseBytes = bytes(_base);

    assert(uint256(_offset + _length) <= _baseBytes.length);

    string memory _tmp = new string(uint256(_length));
    bytes memory _tmpBytes = bytes(_tmp);

    uint256 j = 0;
    for (uint256 i = uint256(_offset); i < uint256(_offset + _length); i++) {
      _tmpBytes[j++] = _baseBytes[i];
    }

    return string(_tmpBytes);
  }
}
