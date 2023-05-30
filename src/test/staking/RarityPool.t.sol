// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import "../../staking/reward/RewardSwap.sol";
import "../../staking/token/RarityPool.sol";
import "../../staking/registry/RareStakingRegistry.sol";
import "../../staking/factory/RarityPoolFactory.sol";
import "../../staking/factory/RewardSwapFactory.sol";
import "rareprotocol/assets/token/ERC20/SuperRareGovToken.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import "@ensdomains/ens-contracts/registry/ReverseRegistrar.sol";
import "@ensdomains/ens-contracts/resolvers/Resolver.sol";
import "@uniswap/v3-core/interfaces/pool/IUniswapV3PoolImmutables.sol";
import {strings} from "arachnid/solidity-stringutils/src/strings.sol";

contract RareStakeTest is Test {
  using strings for *;
  RarityPool public sRare;
  RarityPool public rareStake;
  RareStakingRegistry public registry;
  RarityPoolFactory public factory;
  SuperRareToken public rare;

  address public tokenOwner = address(0xabadabab);
  address public alice = address(0xbeef);
  address public bob = address(0xcafe);
  address public charlie = address(0xdead);
  address public defaultPayee = address(0xaaaa);
  address reverseRegistrar = address(0xdeed);
  address resolver = address(0xdaed);
  address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // taken from mainnet
  address srWethPool = address(0x7685cD3ddD862b8745B1082A6aCB19E14EAA74F3); // taken from mainnet
  uint256 constant initialRare = 1000 * 1e18;

  function contractDeploy() internal {
    vm.startPrank(tokenOwner);

    // Deploy SuperRareToken
    rare = new SuperRareToken();
    rare.init(tokenOwner);

    // Deploy Logic Contracts
    RareStakingRegistry registryLogic = new RareStakingRegistry();
    RarityPoolFactory factoryLogic = new RarityPoolFactory();
    RewardSwapFactory rewardSwapFactoryLogic = new RewardSwapFactory();
    RarityPool sRareTemp = new RarityPool();
    RewardSwap rewardSwapTemp = new RewardSwap();

    // Deploy Proxies
    ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");
    ERC1967Proxy factoryProxy = new ERC1967Proxy(address(factoryLogic), "");
    ERC1967Proxy rewardSwapFactoryProxy = new ERC1967Proxy(address(rewardSwapFactoryLogic), "");

    // Initialize Proxies
    RareStakingRegistry(address(registryProxy)).initialize(
      tokenOwner,
      reverseRegistrar,
      resolver,
      10 minutes,
      1_00,
      10_00,
      address(rare),
      weth,
      defaultPayee
    );
    RewardSwapFactory(address(rewardSwapFactoryProxy)).initialize(
      address(registryProxy),
      address(rewardSwapTemp),
      tokenOwner
    );
    RarityPoolFactory(address(factoryProxy)).initialize(
      address(registryProxy),
      address(sRareTemp),
      address(rewardSwapFactoryProxy),
      tokenOwner
    );

    // Grant Roles
    bytes32 stakingAddressSetterRole = RareStakingRegistry(address(registryProxy)).STAKING_INFO_SETTER_ROLE();
    bytes32 stakingStatAdminRole = RareStakingRegistry(address(registryProxy)).STAKING_STAT_SETTER_ADMIN_ROLE();
    bytes32 swapPoolSetterRole = RareStakingRegistry(address(registryProxy)).SWAP_POOL_SETTER_ROLE();
    bytes32 stakingConfigSetterRole = RareStakingRegistry(address(registryProxy)).STAKING_CONFIG_SETTER_ROLE();

    IAccessControlUpgradeable(address(registryProxy)).grantRole(stakingAddressSetterRole, address(factoryProxy));
    IAccessControlUpgradeable(address(registryProxy)).grantRole(stakingStatAdminRole, address(factoryProxy));
    IAccessControlUpgradeable(address(registryProxy)).grantRole(swapPoolSetterRole, tokenOwner);
    IAccessControlUpgradeable(address(registryProxy)).grantRole(stakingConfigSetterRole, tokenOwner);

    factory = RarityPoolFactory(address(factoryProxy));
    registry = RareStakingRegistry(address(registryProxy));

    factory.deployStaking(tokenOwner);

    vm.etch(reverseRegistrar, address(factory).code);
    vm.etch(resolver, address(factory).code);
    vm.etch(srWethPool, address(factory).code);

    // NOTE:: We need the following 2 mock calls set to initialize the rareStake.
    vm.mockCall(
      reverseRegistrar,
      abi.encodeWithSelector(ReverseRegistrar.node.selector, tokenOwner),
      abi.encode(0x21e5048db69c9250a4d002f25f82936c17b23cf7c98200b012516f58a529047a)
    );
    vm.mockCall(
      resolver,
      abi.encodeWithSelector(
        INameResolver.name.selector,
        0x21e5048db69c9250a4d002f25f82936c17b23cf7c98200b012516f58a529047a
      ),
      abi.encode("")
    );

    RareStakingRegistry.Info memory stakingInfo = registry.getStakingInfoForUser(tokenOwner);

    rareStake = RarityPool(payable(address(stakingInfo.stakingAddress)));
    // registry.setSwapPool(srWethPool, address(rare));
    vm.stopPrank();
  }

  function setUp() public {
    deal(tokenOwner, 100 ether);
    deal(alice, 100 ether);
    deal(bob, 100 ether);
    deal(charlie, 100 ether);
    contractDeploy();
    vm.startPrank(tokenOwner);
    rare.transfer(alice, initialRare);
    rare.transfer(bob, initialRare);
    rare.transfer(charlie, initialRare);
    vm.stopPrank();
  }

  function test_sale_return() public {
    uint256 rareStaked = 10e18;
    uint256 srareSupply = 14e18;
    uint256 unstakeAmount = srareSupply / 2;
    uint256 rareReturned = rareStake.calculateSaleReturn(srareSupply, rareStaked, unstakeAmount);
    uint256 expectedRare = rareStaked / 2;
    if (rareReturned != expectedRare) {
      emit log_named_uint("Expected: expectedRare", expectedRare);
      emit log_named_uint("Actual: rareReturned", rareReturned);
      revert("Incorrect amount of rare to be returned.");
    }
  }

  function test_purchase_return_min() public view {
    uint256 amountToStake = 1e10;
    uint256 supply = rareStake.totalSupply();
    uint256 srare = rareStake.calculatePurchaseReturn(supply, amountToStake);
    require(srare > 0, "Synthetic rare should be greater 0 for small amount");
  }

  function test_purchase_return_too_small() public view {
    uint256 amountToStake = 1e2;
    uint256 supply = rareStake.totalSupply();
    uint256 srare = rareStake.calculatePurchaseReturn(supply, amountToStake);
    require(srare == 0, "Synthetic rare should be 0 for such small amount");
  }

  function test_purchase_return_max() public view {
    uint256 amountToStake = 1e48;
    uint256 supply = rareStake.totalSupply();
    // This will overflow once hitting 1e76
    rareStake.calculatePurchaseReturn(supply, amountToStake);
  }

  function test_purchase_return_too_large() public {
    uint256 amountToStake = 1e76;
    uint256 supply = rareStake.totalSupply();
    vm.expectRevert();
    rareStake.calculatePurchaseReturn(supply, amountToStake);
  }

  function test_stake_sent_rare() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    uint256 expectedBalance = rare.balanceOf(bob) - amountToStake;
    rareStake.stake(amountToStake);
    vm.stopPrank();
    uint256 balance = rare.balanceOf(bob);
    if (balance != expectedBalance) {
      emit log_named_uint("Expected: expectedBalance", expectedBalance);
      emit log_named_uint("Actual: balance", balance);
      revert("Differing balances");
    }
  }

  function test_stake_received_srare() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    uint256 totalSupply = rareStake.totalSupply();
    uint256 expectedSrare = rareStake.calculatePurchaseReturn(totalSupply, amountToStake);
    rareStake.stake(amountToStake);
    vm.stopPrank();
    uint256 balance = rareStake.balanceOf(bob);
    if (expectedSrare != balance) {
      emit log_named_uint("Expected: expectedBalanceAfter", expectedSrare);
      emit log_named_uint("Actual: balanceAfter", balance);
      revert("Differing balances");
    }
  }

  function test_stake_correct_total_amount_staked_on_user_for_registry() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();
    uint256 amountStakedOn = registry.getTotalAmountStakedOnUser(tokenOwner);
    if (amountToStake != amountStakedOn) {
      emit log_named_uint("Expected getTotalAmountStakedOnUser:", amountToStake);
      emit log_named_uint("Actual getTotalAmountStakedOnUser:", amountStakedOn);
      revert("Different amount staked");
    }
  }

  function test_stake_correct_total_staked_amount_on_registry() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();
    uint256 amountStakedOn = registry.getTotalAmountStakedByUser(bob);
    if (amountToStake != amountStakedOn) {
      emit log_named_uint("Expected getTotalAmountStakedByUser:", amountToStake);
      emit log_named_uint("Actual getTotalAmountStakedByUser:", amountStakedOn);
      revert("Different amount staked");
    }
  }

  function test_unstake_receive_rare_burn() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    uint256 burnPercentage = registry.getDeflationaryPercentage();
    uint256 expectedBalance = rare.balanceOf(bob) - ((amountToStake * burnPercentage) / 10_000);
    rareStake.stake(amountToStake);
    uint256 amountToUnstake = rareStake.balanceOf(bob);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();
    uint256 balance = rare.balanceOf(bob);
    if (balance != expectedBalance) {
      emit log_named_uint("Expected: expectedBalance", expectedBalance);
      emit log_named_uint("Actual: balance", balance);
      revert("Differing balances");
    }
  }

  function test_unstake_remove_srare() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    uint256 expectedBalance = 0;
    uint256 expectedSupply = rareStake.totalSupply();
    rareStake.stake(amountToStake);
    uint256 amountToUnstake = rareStake.balanceOf(bob);
    rareStake.unstake(amountToUnstake);
    uint256 sRareSupply = rareStake.totalSupply();
    uint256 balance = rareStake.balanceOf(bob);
    vm.stopPrank();
    if (balance != expectedBalance) {
      emit log_named_uint("Expected: expectedBalance", expectedBalance);
      emit log_named_uint("Actual: balance", balance);
      revert("Differing balances");
    }
    if (sRareSupply != expectedSupply) {
      emit log_named_uint("Expected: expectedSupply", expectedSupply);
      emit log_named_uint("Actual: sRareSupply", sRareSupply);
      revert("Differing total Supply for synthetic RARE");
    }
  }

  function test_unstake_burn() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    uint256 burnPercentage = registry.getDeflationaryPercentage();
    uint256 expectedSupply = rare.totalSupply() - ((amountToStake * burnPercentage) / 10_000);
    rareStake.stake(amountToStake);
    uint256 amountToUnstake = rareStake.balanceOf(bob);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();
    uint256 supply = rare.totalSupply();
    if (supply != expectedSupply) {
      emit log_named_uint("Expected: expectedSupply", expectedSupply);
      emit log_named_uint("Actual: supply", supply);
      revert("Differing total supplies for RARE after burn");
    }
  }

  function test_unstake_correct_total_staked_amount_on_registry() public {
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    uint256 srareBalance = rareStake.balanceOf(bob);
    uint256 amountToUnstake = rareStake.balanceOf(bob) / 2;
    uint256 expectedAmountStaked = amountToStake -
      rareStake.calculateSaleReturn(srareBalance, amountToStake, amountToUnstake);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();
    uint256 amountStaked = registry.getTotalAmountStakedByUser(bob);
    if (amountStaked != expectedAmountStaked) {
      emit log_named_uint("Expected: expectedAmountStaked", expectedAmountStaked);
      emit log_named_uint("Actual: amountStaked", amountStaked);
      revert("Differing balances");
    }
  }

  function test_round_1_starts_on_creation() public {
    uint256 currentRound = rareStake.getCurrentRound();
    uint256 expectedRound = 1;
    if (currentRound != expectedRound) {
      emit log_named_uint("Expected: currentRound", currentRound);
      emit log_named_uint("Actual: currentRound", currentRound);
      revert("Initial round is not round 1.");
    }
  }

  function test_round_increases_after_min_limit_reached() public {
    forwardNPeriods(1);
    uint256 currentRound = rareStake.getCurrentRound();
    uint256 expectedRound = 2;
    if (currentRound != expectedRound) {
      emit log_named_uint("Expected: currentRound", currentRound);
      emit log_named_uint("Actual: currentRound", currentRound);
      revert("Round did not increasse when expected.");
    }
  }

  function test_round_only_increases_only_once_if_no_action_occurs() public {
    forwardNPeriods(100);
    uint256 currentRound = rareStake.getCurrentRound();
    uint256 expectedRound = 2;
    if (currentRound != expectedRound) {
      emit log_named_uint("Expected: currentRound", currentRound);
      emit log_named_uint("Actual: currentRound", currentRound);
      revert("Round did not increasse when expected.");
    }
  }

  function test_rewards_sent_to_default_payee_if_no_stakers_no_snapshot() public {
    uint256 depositedReward = 100 * 1e18;
    uint256 expectedBalance = rare.balanceOf(defaultPayee) + depositedReward;
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    forwardNPeriods(1);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256 balance = rare.balanceOf(defaultPayee);
    if (balance != expectedBalance) {
      emit log_named_uint("Expected: expectedBalance", expectedBalance);
      emit log_named_uint("Actual: balance", balance);
      revert("Differing balances");
    }
  }

  function test_rewards_sent_to_default_payee_if_no_stakers_with_snapshot() public {
    uint256 depositedReward = 100 * 1e18;
    uint256 expectedBalance = rare.balanceOf(defaultPayee) + depositedReward;
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    forwardNPeriods(1);
    rareStake.takeSnapshot();
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256 balance = rare.balanceOf(defaultPayee);
    if (balance != expectedBalance) {
      emit log_named_uint("Expected: expectedBalance", expectedBalance);
      emit log_named_uint("Actual: balance", balance);
      revert("Differing balances");
    }
  }

  function test_addRewards_fails_adding_for_others() public {
    uint256 depositedReward = 100 * 1e18;
    vm.startPrank(alice);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    vm.stopPrank();
    vm.startPrank(tokenOwner);
    vm.expectRevert();
    rareStake.addRewards(alice, depositedReward);
    vm.stopPrank();
  }

  function test_rewards_accumulate_for_round() public {
    // NOTE: This works because at creation time, the creator of the pool is given 1 SRARE.
    uint256 depositedReward = 100 * 1e18;
    uint256 expectedRewards = 2 * depositedReward;
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256 rewards = rareStake.getRoundRewards(1);
    if (rewards != expectedRewards) {
      emit log_named_uint("Expected: expectedRewards", expectedRewards);
      emit log_named_uint("Actual: rewards", rewards);
      revert("Differing balances");
    }
  }

  function test_user_rewards_accurate_for_round() public {
    uint256 depositedReward = 100 * 1e18;

    // Clear token owner's stake since is very little
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();

    // Stake as Bob
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Stake as Alice
    vm.startPrank(alice);
    rare.increaseAllowance(address(registry), initialRare);
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Move forward 1 period
    forwardNPeriods(1);

    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256[] memory rounds = new uint256[](1);
    rounds[0] = 2;
    uint256 rewardsAlice = rareStake.getHistoricalRewardsForUserForRounds(alice, rounds);
    uint256 rewardsBob = rareStake.getHistoricalRewardsForUserForRounds(bob, rounds);
    uint256 rewardsTotal = rareStake.getRoundRewards(rounds[0]);
    uint256 leftOverFromClaim = rewardsTotal - rewardsAlice - rewardsBob;

    if (leftOverFromClaim > 1) {
      emit log_named_uint("rewardsAlice", rewardsAlice);
      emit log_named_uint("rewardsBob", rewardsBob);
      emit log_named_uint("rewardsTotal", rewardsTotal);
      emit log_named_uint("rewardsTotal - rewardsAlice - rewardsBob", leftOverFromClaim);
      revert("Expected: rewardsTotal - rewardsAlice - rewardsBob > 1");
    }
  }

  function test_claim_multiple_rounds() public {
    uint256 depositedReward = 100 * 1e18;

    // Clear token owner's stake since is very little
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();

    // Stake as Bob
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Move forward 1 period
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    // Move forward 1 period and takesnapshot so future rewards accumulate next round
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    // Add more rewards for found 3
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256[] memory rounds = new uint256[](2);
    rounds[0] = 2;
    rounds[1] = 3;

    // Move forward 1 to claim
    forwardNPeriods(1);

    uint256 balanceBefore = rare.balanceOf(bob);
    uint256 rewardsBob = rareStake.getClaimableRewardsForUserForRounds(bob, rounds);
    rareStake.claimRewardsForRounds(bob, rounds);
    uint256 balanceAfter = rare.balanceOf(bob);

    if (balanceAfter - balanceBefore != rewardsBob) {
      emit log_named_uint("balanceBefore", balanceBefore);
      emit log_named_uint("balanceAfter", balanceAfter);
      emit log_named_uint("rewardsBob", rewardsBob);
      emit log_named_uint("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
      revert("balanceAfter - balanceBefore != rewardsBob");
    }
  }

  function test_claim_stakee_percentage() public {
    uint256 depositedReward = 100 * 1e18;

    // Clear token owner's stake since is very little
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();

    // Stake as Bob
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Move forward 1 period
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    // Move forward 1 period and takesnapshot so future rewards accumulate next round
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    uint256[] memory rounds = new uint256[](1);
    rounds[0] = 2;

    // Move forward 1 to claim
    forwardNPeriods(1);

    // Set stakee percentage
    vm.prank(tokenOwner);
    registry.setStakeePercentage(1_00);

    uint256 balanceBefore = rare.balanceOf(tokenOwner);
    uint256 rewardsBob = rareStake.getClaimableRewardsForUserForRounds(bob, rounds);
    uint256 stakeeRewards = (1_00 * rewardsBob) / 100_00;

    // Claim for bob
    vm.prank(bob);
    rareStake.claimRewardsForRounds(bob, rounds);

    uint256 balanceAfter = rare.balanceOf(tokenOwner);

    if (balanceAfter - balanceBefore != stakeeRewards) {
      emit log_named_uint("balanceBefore", balanceBefore);
      emit log_named_uint("balanceAfter", balanceAfter);
      emit log_named_uint("stakeeRewards", stakeeRewards);
      emit log_named_uint("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
      revert("balanceAfter - balanceBefore != stakeeRewards");
    }
  }

  function test_claim_claimer_percentage() public {
    uint256 depositedReward = 100 * 1e18;

    // Clear token owner's stake since is very little
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();

    // Stake as Bob
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Move forward 1 period
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    // Move forward 1 period and takesnapshot so future rewards accumulate next round
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    uint256[] memory rounds = new uint256[](1);
    rounds[0] = 2;

    // Move forward 1 to claim
    forwardNPeriods(1);

    // Set Claimer percentage
    vm.prank(bob);
    registry.setClaimerPercentage(1_00);

    uint256 balanceBefore = rare.balanceOf(alice);
    uint256 rewardsBob = rareStake.getClaimableRewardsForUserForRounds(bob, rounds);
    uint256 claimerRewards = (1_00 * rewardsBob) / 100_00;

    // Claim for bob
    vm.prank(alice);
    rareStake.claimRewardsForRounds(bob, rounds);

    uint256 balanceAfter = rare.balanceOf(alice);

    if (balanceAfter - balanceBefore != claimerRewards) {
      emit log_named_uint("balanceBefore", balanceBefore);
      emit log_named_uint("balanceAfter", balanceAfter);
      emit log_named_uint("claimerRewards", claimerRewards);
      emit log_named_uint("balanceAfter - balanceBefore", balanceAfter - balanceBefore);
      revert("balanceAfter - balanceBefore != claimerRewards");
    }
  }

  function test_cannot_claim_same_round() public {
    uint256 depositedReward = 100 * 1e18;

    // Clear token owner's stake since is very little
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();

    // Stake as Bob
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Stake as alice
    vm.startPrank(alice);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStakeAlice = 100 * 1e18;
    rareStake.stake(amountToStakeAlice);
    vm.stopPrank();

    // Move forward 1 period
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    // Move forward 1 period and takesnapshot so future rewards accumulate next round
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    // Add more rewards for found 3
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256[] memory rounds = new uint256[](2);
    rounds[0] = 2;
    rounds[1] = 3;

    // Move forward 1 to claim
    forwardNPeriods(1);

    uint256 rewardsBob = rareStake.getClaimableRewardsForUserForRounds(bob, rounds);
    rareStake.claimRewardsForRounds(bob, rounds);
    vm.expectRevert();
    rareStake.claimRewardsForRounds(bob, rounds);
  }

  function test_cannot_claim_current_round() public {
    uint256 depositedReward = 100 * 1e18;

    // Clear token owner's stake since is very little
    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), depositedReward);
    rareStake.stake(depositedReward);
    uint256 amountToUnstake = rareStake.balanceOf(tokenOwner);
    rareStake.unstake(amountToUnstake);
    vm.stopPrank();

    // Stake as Bob
    vm.startPrank(bob);
    rare.increaseAllowance(address(registry), initialRare);
    uint256 amountToStake = 10 * 1e18;
    rareStake.stake(amountToStake);
    vm.stopPrank();

    // Move forward 1 period
    forwardNPeriods(1);
    rareStake.takeSnapshot();

    vm.startPrank(tokenOwner);
    rare.increaseAllowance(address(registry), 2 * depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    rareStake.addRewards(tokenOwner, depositedReward);
    vm.stopPrank();

    uint256[] memory rounds = new uint256[](1);
    rounds[0] = 2;

    vm.expectRevert();
    rareStake.claimRewardsForRounds(bob, rounds);
  }

  function test_name_look_up_with_ens_name() public {
    vm.mockCall(
      resolver,
      abi.encodeWithSelector(
        INameResolver.name.selector,
        0x21e5048db69c9250a4d002f25f82936c17b23cf7c98200b012516f58a529047a
      ),
      abi.encode("xcopy.eth")
    );

    string memory name = rareStake.name();
    string memory expectedName = "Synthetic RARE | xcopy";
    if (!name.toSlice().equals(expectedName.toSlice())) {
      emit log_named_string("Expected name", expectedName);
      emit log_named_string("Actual name", name);
      revert("Wrong name");
    }

    string memory symbol = rareStake.symbol();
    string memory expectedSymbol = "xRARE_XCOPY";
    if (!symbol.toSlice().equals(expectedSymbol.toSlice())) {
      emit log_named_string("Expected symbol", expectedSymbol);
      emit log_named_string("Actual symbol", symbol);
      revert("Wrong symbol");
    }
  }

  function test_name_look_up_without_ens_name() public {
    vm.mockCall(
      resolver,
      abi.encodeWithSelector(
        INameResolver.name.selector,
        0x21e5048db69c9250a4d002f25f82936c17b23cf7c98200b012516f58a529047a
      ),
      abi.encode("")
    );

    string memory name = rareStake.name();
    string memory expectedName = "Synthetic RARE | 0x0000bada";
    if (!name.toSlice().equals(expectedName.toSlice())) {
      emit log_named_string("Expected name", expectedName);
      emit log_named_string("Actual name", name);
      revert("Wrong name");
    }

    string memory symbol = rareStake.symbol();
    string memory expectedSymbol = "xRARE_0x0000bada";
    if (!symbol.toSlice().equals(expectedSymbol.toSlice())) {
      emit log_named_string("Expected symbol", expectedName);
      emit log_named_string("Actual symbol", expectedSymbol);
      revert("Wrong symbol");
    }
  }

  /*//////////////////////////////////////////////////////////////////////////
                          Helper Functions
  //////////////////////////////////////////////////////////////////////////*/
  function forwardNPeriods(uint256 n) public {
    // Jump forward one period
    uint256 periodLength = registry.getPeriodLength();
    vm.warp(block.timestamp + (periodLength * n));
  }
}
