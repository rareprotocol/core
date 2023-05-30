// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v3-core/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/libraries/OracleLibrary.sol";

import {IRewardSwap} from "./IRewardSwap.sol";
import {IRarityPool} from "../token/IRarityPool.sol";
import {IRareStakingRegistry} from "../registry/IRareStakingRegistry.sol";

/// @author charlescrain
/// @title RewardSwap
/// @notice The Staked ERC20 contract that allows users to stake/unstake/claim rewards/reward swaps.
/// @dev It is one base user per contract. This is the implementation contract for a beacon proxy.
contract RewardSwap is IRewardSwap, ReentrancyGuard, Initializable {
  using SafeCast for uint256;
  using SafeCast for uint128;

  /*//////////////////////////////////////////////////////////////////////////
                          Private Contract Storage
  //////////////////////////////////////////////////////////////////////////*/
  // Address of the staking registry
  IRareStakingRegistry private stakingRegistry;

  // Address of the staking pool
  IRarityPool private stakingPool;

  /*//////////////////////////////////////////////////////////////////////////
                              Initializer
  //////////////////////////////////////////////////////////////////////////*/
  function initialize(address _stakingRegistry, address _stakingPool) external initializer {
    stakingRegistry = IRareStakingRegistry(_stakingRegistry);
    stakingPool = IRarityPool(_stakingPool);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Public Write Functions
  //////////////////////////////////////////////////////////////////////////*/
  /// @inheritdoc IRewardSwap
  function rewardSwap(
    address _tokenOut,
    uint256 _minAmountOut,
    uint128 _rareIn
  ) external nonReentrant {
    IERC20 rare = IERC20(stakingRegistry.getRareAddress());

    // Empty any excess $RARE to the staking pool
    if (rare.balanceOf(address(this)) > 0) {
      rare.transfer(address(stakingPool), rare.balanceOf(address(this)));
    }
    // If ETH, check balance
    if (_tokenOut == address(0) && address(this).balance < _minAmountOut) {
      revert InsufficientFunds();
    }

    // If ERC20, check balance
    if (_tokenOut != address(0) && IERC20(_tokenOut).balanceOf(address(this)) < _minAmountOut) {
      revert InsufficientFunds();
    }

    // Check if is $RARE address
    if (_tokenOut == address(rare)) {
      revert CannotSwapRareForRare();
    }

    // Estimate the price
    uint256 amountOut = estimateRarePrice(_tokenOut, _rareIn);

    // Ensure that amount to return meets _minAmoutOut requirements
    if (amountOut < _minAmountOut) {
      revert RarePriceTooLow();
    }

    // Add the $RARE to the staking pool as rewards
    stakingPool.addRewards(msg.sender, _rareIn);

    // If ETH, send the swap amount
    if (_tokenOut == address(0)) {
      Address.sendValue(payable(msg.sender), amountOut);
    } else {
      // Send the swap amount as ERC20
      IERC20(_tokenOut).transfer(msg.sender, amountOut);
    }

    emit RewardSwap(msg.sender, _tokenOut, amountOut, _rareIn);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          External/Public Read Functions
  //////////////////////////////////////////////////////////////////////////*/
  /// @inheritdoc IRewardSwap
  function estimateRarePrice(address _tokenOut, uint128 _rareAmountIn) public view returns (uint256) {
    address weth = stakingRegistry.getWethAddress();
    // Null address implies ETH
    address tokenOut = _tokenOut == address(0) ? weth : _tokenOut;
    address poolOut = stakingRegistry.getSwapPool(tokenOut);

    // If poolOut is the null address and the token out isn't the WETH addres, it's unsupported
    if (poolOut == address(0) && tokenOut != weth) {
      revert UnsupportedERC20Token();
    }

    uint32 secondsAgo = 30 minutes;
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = secondsAgo;
    secondsAgos[1] = 0;

    // Look up cumulative ticks for 30 minutes
    (int56[] memory tickCumulatives, ) = IUniswapV3Pool(stakingRegistry.getSwapPool(stakingRegistry.getRareAddress()))
      .observe(secondsAgos);

    // Calculate the the tick to obtain a quote
    int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
    int24 tick = int24(tickCumulativesDelta / int32(secondsAgo));
    // Always round to negative infinity
    if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(secondsAgo) != 0)) {
      tick--;
    }

    // Get ETH/WETH amount for the $RARE in
    uint256 ethAmount = ((
      OracleLibrary.getQuoteAtTick(tick, _rareAmountIn.toUint128(), stakingRegistry.getRareAddress(), weth)
    ) * (100_00 + stakingRegistry.getDiscountPercentage())) / 100_00;

    // If tokenOut is WETH we can simply return this amount for the price
    if (tokenOut == weth) {
      return ethAmount;
    }

    // If checking for Other_Token/RARE price, look up pool pair for Other_token/WETH
    (int56[] memory otherTickCumulatives, ) = IUniswapV3Pool(poolOut).observe(secondsAgos);
    int56 otherTickCumulativesDelta = otherTickCumulatives[1] - otherTickCumulatives[0];
    int24 otherTick = int24(otherTickCumulativesDelta / int32(secondsAgo));

    return OracleLibrary.getQuoteAtTick(otherTick, ethAmount.toUint128(), weth, tokenOut);
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Receive
  //////////////////////////////////////////////////////////////////////////*/

  receive() external payable {}
}
