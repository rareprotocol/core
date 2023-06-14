// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../staking/reward/RewardAccumulator.sol";
import "../../staking/token/RarityPool.sol";
import "../../staking/registry/RareStakingRegistry.sol";
import "../../staking/factory/RarityPoolFactory.sol";
import "../../staking/factory/RewardAccumulatorFactory.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import "@ensdomains/ens-contracts/registry/ReverseRegistrar.sol";
import "@ensdomains/ens-contracts/resolvers/Resolver.sol";
import "@uniswap/v3-core/interfaces/pool/IUniswapV3PoolImmutables.sol";
import {strings} from "arachnid/solidity-stringutils/src/strings.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";


contract RarityPoolDebugTest is Test {
  using strings for *;
  RarityPool public rareStake;
  IERC20 public rare;

  address public john = address(0x337101dEF3EEb6F06e071EFE02216274507937Bb);
  address public stakee = address(0xa7695409c5Fef39A8367759A279386302a683b9A);

  function setUp() public {
    deal(john, 100 ether);
    deal(stakee, 100 ether);
    rareStake = RarityPool(0x2f9D5cE57b82F93a0694bfd645b2966192ba3102);
    rare = IERC20(0x3c95F1764a9b72a49d772ba09F1b81B993cF7E48);
  }
  function test_debug() public {
    // how much did the stakee get at the block vs total round rewards?
  }
}