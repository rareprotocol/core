// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IApprovedTokenRegistry} from "rareprotocol/aux/registry/interfaces/IApprovedTokenRegistry.sol";
import {IStakingSettings} from "rareprotocol/aux/marketplace/IStakingSettings.sol";
import {IMarketplaceSettings} from "rareprotocol/aux/marketplace/IMarketplaceSettings.sol";
import {ISpaceOperatorRegistry} from "rareprotocol/aux/registry/interfaces/ISpaceOperatorRegistry.sol";
import {IPayments} from "rareprotocol/aux/payments/IPayments.sol";
import {IRoyaltyEngineV1} from "royalty-registry/IRoyaltyEngineV1.sol";

import {IRareStakingRegistry} from "../../staking/registry/IRareStakingRegistry.sol";

library MarketConfig {
  struct Config {
    address networkBeneficiary;
    IMarketplaceSettings marketplaceSettings;
    ISpaceOperatorRegistry spaceOperatorRegistry;
    IRoyaltyEngineV1 royaltyEngine;
    IPayments payments;
    IApprovedTokenRegistry approvedTokenRegistry;
    IStakingSettings stakingSettings;
    IRareStakingRegistry stakingRegistry;
  }
  event NetworkBeneficiaryUpdated(address indexed newNetworkBeneficiary);
  event MarketplaceSettingsUpdated(address indexed newMarketplaceSettings);
  event SpaceOperatorRegistryUpdated(address indexed newSpaceOperatorRegistry);
  event RoyaltyEngineUpdated(address indexed newRoyaltyEngine);
  event PaymentsUpdated(address indexed newPayments);
  event ApprovedTokenRegistryUpdated(address indexed newApprovedTokenRegistry);
  event StakingSettingsUpdated(address indexed newStakingSettings);
  event StakingRegistryUpdated(address indexed newStakingRegistry);

  function generateMarketConfig(
    address _networkBeneficiary,
    address _marketplaceSettings,
    address _spaceOperatorRegistry,
    address _royaltyEngine,
    address _payments,
    address _approvedTokenRegistry,
    address _stakingSettings,
    address _stakingRegistry
  ) public pure returns (Config memory) {
    return
      MarketConfig.Config(
        _networkBeneficiary,
        IMarketplaceSettings(_marketplaceSettings),
        ISpaceOperatorRegistry(_spaceOperatorRegistry),
        IRoyaltyEngineV1(_royaltyEngine),
        IPayments(_payments),
        IApprovedTokenRegistry(_approvedTokenRegistry),
        IStakingSettings(_stakingSettings),
        IRareStakingRegistry(_stakingRegistry)
      );
  }

  function updateNetworkBeneficiary(Config storage _config, address _networkBeneficiary) public {
    _config.networkBeneficiary = _networkBeneficiary;
    emit NetworkBeneficiaryUpdated(_networkBeneficiary);
  }

  function updateMarketplaceSettings(Config storage _config, address _marketplaceSettings) public {
    _config.marketplaceSettings = IMarketplaceSettings(_marketplaceSettings);
    emit MarketplaceSettingsUpdated(_marketplaceSettings);
  }

  function updateSpaceOperatorRegistry(Config storage _config, address _spaceOperatorRegistry) public {
    _config.spaceOperatorRegistry = ISpaceOperatorRegistry(_spaceOperatorRegistry);
    emit SpaceOperatorRegistryUpdated(_spaceOperatorRegistry);
  }

  function updateRoyaltyEngine(Config storage _config, address _royaltyEngine) public {
    _config.royaltyEngine = IRoyaltyEngineV1(_royaltyEngine);
    emit RoyaltyEngineUpdated(_royaltyEngine);
  }

  function updatePayments(Config storage _config, address _payments) public {
    _config.payments = IPayments(_payments);
    emit PaymentsUpdated(_payments);
  }

  function updateApprovedTokenRegistry(Config storage _config, address _approvedTokenRegistry) public {
    _config.approvedTokenRegistry = IApprovedTokenRegistry(_approvedTokenRegistry);
    emit ApprovedTokenRegistryUpdated(_approvedTokenRegistry);
  }

  function updateStakingSettings(Config storage _config, address _stakingSettings) public {
    _config.stakingSettings = IStakingSettings(_stakingSettings);
    emit StakingSettingsUpdated(_stakingSettings);
  }

  function updateStakingRegistry(Config storage _config, address _stakingRegistry) public {
    _config.stakingRegistry = IRareStakingRegistry(_stakingRegistry);
    emit StakingRegistryUpdated(_stakingRegistry);
  }
}
