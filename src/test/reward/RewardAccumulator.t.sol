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
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/utils/math/Math.sol";
import "@ensdomains/ens-contracts/registry/ReverseRegistrar.sol";
import "@ensdomains/ens-contracts/resolvers/Resolver.sol";
import {strings} from "arachnid/solidity-stringutils/src/strings.sol";

contract TestRare is ERC20 {
  constructor() ERC20("Rare", "RARE") {
    _mint(msg.sender, 1_000_000_000 ether);
  }
}

contract RewardSwapTest is Test {
  using strings for *;
  RewardAccumulator rewardSwap;
  RareStakingRegistry registry;
  RarityPoolFactory factory;
  TestRare rare;
  IERC20 erc20Token;

  address tokenOwner = address(0xabadabab);
  address alice = address(0xbeef);
  address bob = address(0xcafe);
  address charlie = address(0xdead);
  address defaultPayee = address(0xaaaa);
  address fakeStakingPool = address(0x20);
  address reverseRegistrar = address(0xdeed);
  address resolver = address(0xdaed);
  address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // taken from mainnet
  address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // taken from mainnet
  address srWethPool = address(0x7685cD3ddD862b8745B1082A6aCB19E14EAA74F3); // taken from mainnet
  address usdcEthPool = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640); // taken from mainnet
  address generalErc20Pool = address(0xeeee);
  uint256 constant initialRare = 1000 * 1e18;

  function contractDeploy() internal {
    vm.startPrank(tokenOwner);

    // Deploy TestRare
    rare = new TestRare();

    // Deploy Arbitrary ERC20 Token. We use Rare token again for simpl
    TestRare tmpToken = new TestRare();
    erc20Token = IERC20(address(tmpToken));

    // Deploy Logic Contracts
    RareStakingRegistry registryLogic = new RareStakingRegistry();
    RewardAccumulatorFactory rewardSwapFactoryLogic = new RewardAccumulatorFactory();
    RewardAccumulator rewardSwapTemp = new RewardAccumulator();
    // Deploy Proxies
    ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");
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
    RewardAccumulatorFactory(address(rewardSwapFactoryProxy)).initialize(
      address(rewardSwapTemp),
      tokenOwner
    );

    // Grant Roles
    bytes32 swapPoolSetterRole = RareStakingRegistry(address(registryProxy)).SWAP_POOL_SETTER_ROLE();
    bytes32 stakingConfigSetterRole = RareStakingRegistry(address(registryProxy)).STAKING_CONFIG_SETTER_ROLE();

    IAccessControlUpgradeable(address(registryProxy)).grantRole(swapPoolSetterRole, tokenOwner);
    IAccessControlUpgradeable(address(registryProxy)).grantRole(stakingConfigSetterRole, tokenOwner);

    vm.mockCall(
      srWethPool,
      abi.encodeWithSelector(IUniswapV3PoolImmutables.token0.selector),
      abi.encode(address(rare))
    );
    vm.mockCall(
      srWethPool,
      abi.encodeWithSelector(IUniswapV3PoolImmutables.token1.selector),
      abi.encode(address(weth))
    );

    vm.mockCall(
      usdcEthPool,
      abi.encodeWithSelector(IUniswapV3PoolImmutables.token0.selector),
      abi.encode(address(usdc))
    );
    vm.mockCall(
      usdcEthPool,
      abi.encodeWithSelector(IUniswapV3PoolImmutables.token1.selector),
      abi.encode(address(weth))
    );

    vm.mockCall(
      generalErc20Pool,
      abi.encodeWithSelector(IUniswapV3PoolImmutables.token0.selector),
      abi.encode(address(erc20Token))
    );
    vm.mockCall(
      generalErc20Pool,
      abi.encodeWithSelector(IUniswapV3PoolImmutables.token1.selector),
      abi.encode(address(weth))
    );

    vm.mockCall(
      fakeStakingPool,
      abi.encodeWithSelector(RarityPool.getStakingRegistry.selector),
      abi.encode(address(registryProxy))
    );

    RareStakingRegistry(address(registryProxy)).setSwapPool(srWethPool, address(rare));
    RareStakingRegistry(address(registryProxy)).setSwapPool(usdcEthPool, address(usdc));
    RareStakingRegistry(address(registryProxy)).setSwapPool(generalErc20Pool, address(erc20Token));

    rewardSwap = RewardAccumulator(RewardAccumulatorFactory(address(rewardSwapFactoryProxy)).deployRewardSwap(fakeStakingPool));

    vm.etch(reverseRegistrar, address(factory).code);
    vm.etch(resolver, address(factory).code);
    vm.etch(srWethPool, address(factory).code);
    vm.etch(usdcEthPool, address(factory).code);
    vm.etch(generalErc20Pool, address(factory).code);
    vm.etch(fakeStakingPool, address(factory).code);

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

  function test_estimateRarePrice_eth() public {
    // Set WETH/RARE observe call to a valid response. Can be recreated by:
    // observe([1800, 0]) on mainnet at block 17097273.

    // Mock args
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = 1800;
    secondsAgos[1] = 0;

    // Mock return value
    int56[] memory ticksCumulative = new int56[](2);
    ticksCumulative[0] = -4610944883851;
    ticksCumulative[1] = -4611118763851;
    uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
    secondsPerLiquidityCumulativeX128s[0] = 2640452278406203878406677;
    secondsPerLiquidityCumulativeX128s[1] = 2641198466758139176465402;
    // Set mock call
    vm.mockCall(
      srWethPool,
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector, secondsAgos),
      abi.encode(ticksCumulative, secondsPerLiquidityCumulativeX128s)
    );

    uint256 expectedAmount = 70196868766490808; // 0.070196868766490808 ether
    uint256 amount = rewardSwap.estimateRarePrice(address(0), 1000e18);
    if (amount != expectedAmount) {
      emit log_named_uint("Expected: expectedAmount", expectedAmount);
      emit log_named_uint("Actual: amount", amount);
      revert("Estimated rare price incorrect.");
    }
  }

  function test_estimateRarePrice_unsupported_erc20() public {}

  function test_estimateRarePrice_erc20() public {
    mockRareEthPrice();
    mockRareUSDCPrice();

    uint256 expectedAmount = 125521446; // 125.521446 USDC
    uint256 amount = rewardSwap.estimateRarePrice(usdc, 1000e18);
    if (amount != expectedAmount) {
      emit log_named_uint("Expected: expectedAmount", expectedAmount);
      emit log_named_uint("Actual: amount", amount);
      revert("Estimated rare price incorrect.");
    }
  }

  function test_reward_swap_eth() public {
    mockRareEthPrice();
    mockAddRewards(bob, 1000e18);

    uint256 expectedAmount = 70196868766490808; // 0.070196868766490808 ether
    uint256 ethBalancePre = bob.balance;

    vm.deal(payable(rewardSwap), 1 ether);

    vm.prank(bob);
    rewardSwap.rewardSwap(address(0), 70196868766490808, 1000e18);

    uint256 balanceDiff = bob.balance - ethBalancePre;
    if (balanceDiff != expectedAmount) {
      emit log_named_uint("Expected: expectedAmount", expectedAmount);
      emit log_named_uint("Actual: balanceDiff", balanceDiff);
      revert("Incorrect amount");
    }
  }

  function test_reward_swap_erc20() public {
    mockRareEthPrice();
    mockRareGeneralErc20Price();
    mockAddRewards(bob, 1000e18);

    uint256 expectedAmount = 125521446; // 125.521446 USDC
    uint256 balancePre = erc20Token.balanceOf(bob);

    vm.prank(tokenOwner);
    erc20Token.transfer(address(rewardSwap), 1e18);

    vm.prank(bob);
    rewardSwap.rewardSwap(address(erc20Token), 125521446, 1000e18);

    uint256 balanceDiff = erc20Token.balanceOf(bob) - balancePre;
    if (balanceDiff != expectedAmount) {
      emit log_named_uint("Expected: expectedAmount", expectedAmount);
      emit log_named_uint("Actual: balanceDiff", balanceDiff);
      revert("Incorrect amount");
    }
  }

  function test_reward_swap_eth_rare_price_low() public {
    mockRareEthPrice();
    mockAddRewards(bob, 1000e18);

    vm.deal(payable(rewardSwap), 1 ether);

    vm.expectRevert();
    vm.prank(bob);
    rewardSwap.rewardSwap(address(0), 70196868766490809, 1000e18);
  }

  function test_reward_swap_erc20_rare_price_low() public {
    mockRareEthPrice();
    mockRareGeneralErc20Price();
    mockAddRewards(bob, 1000e18);

    vm.prank(tokenOwner);
    erc20Token.transfer(address(rewardSwap), 1e18);

    vm.expectRevert();
    vm.prank(bob);
    rewardSwap.rewardSwap(address(erc20Token), 125521447, 1000e18);
  }

  function mockAddRewards(address _donor, uint256 _amount) public {
    // Set mock call
    vm.mockCall(fakeStakingPool, abi.encodeWithSelector(IRarityPool.addRewards.selector, _donor, _amount), "");
  }

  function mockRareEthPrice() public {
    // Set WETH/RARE observe call to a valid response. Can be recreated by:
    // observe([1800, 0]) on mainnet at block 17097273.

    // Mock args
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = 1800;
    secondsAgos[1] = 0;

    // Mock return value
    int56[] memory ticksCumulative = new int56[](2);
    ticksCumulative[0] = -4610944883851;
    ticksCumulative[1] = -4611118763851;
    uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
    secondsPerLiquidityCumulativeX128s[0] = 2640452278406203878406677;
    secondsPerLiquidityCumulativeX128s[1] = 2641198466758139176465402;
    // Set mock call
    vm.mockCall(
      srWethPool,
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector, secondsAgos),
      abi.encode(ticksCumulative, secondsPerLiquidityCumulativeX128s)
    );
  }

  function mockRareGeneralErc20Price() public {
    // Use the USDC/WETH observe call to a valid response. Can be recreated by:
    // observe([1800, 0]) on mainnet at block 17239407.

    // Mock args
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = 1800;
    secondsAgos[1] = 0;

    // Mock return value
    int56[] memory ticksCumulative = new int56[](2);
    ticksCumulative[0] = 12684871784879;
    ticksCumulative[1] = 12685234361183;
    uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
    secondsPerLiquidityCumulativeX128s[0] = 151655214766370152634371726292;
    secondsPerLiquidityCumulativeX128s[1] = 151655249710943235760705634699;
    // Set mock call
    vm.mockCall(
      generalErc20Pool,
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector, secondsAgos),
      abi.encode(ticksCumulative, secondsPerLiquidityCumulativeX128s)
    );
  }

  function mockRareUSDCPrice() public {
    // Set USDC/WETH observe call to a valid response. Can be recreated by:
    // observe([1800, 0]) on mainnet at block 17239407.

    // Mock args
    uint32[] memory secondsAgos = new uint32[](2);
    secondsAgos[0] = 1800;
    secondsAgos[1] = 0;

    // Mock return value
    int56[] memory ticksCumulative = new int56[](2);
    ticksCumulative[0] = 12684871784879;
    ticksCumulative[1] = 12685234361183;
    uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
    secondsPerLiquidityCumulativeX128s[0] = 151655214766370152634371726292;
    secondsPerLiquidityCumulativeX128s[1] = 151655249710943235760705634699;
    // Set mock call
    vm.mockCall(
      usdcEthPool,
      abi.encodeWithSelector(IUniswapV3PoolDerivedState.observe.selector, secondsAgos),
      abi.encode(ticksCumulative, secondsPerLiquidityCumulativeX128s)
    );
  }
}
