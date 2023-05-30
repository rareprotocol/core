#!/bin/sh

echo "Running Stacking Rewards Script..."

forge script script/staking/RareStakeRewardDepositor.s.sol:RareStakeRewardDepositor --broadcast --rpc-url "${ETH_RPC_URL}" --ffi
