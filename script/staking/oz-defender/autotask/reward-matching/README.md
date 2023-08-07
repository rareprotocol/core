# Reward Matching

## Purpose
This autotask responds to events on the bazaar contracts when sales occur. Its job is to match rewards flowing into rarity pools as an adoption incentive and distribution mechanism.

## Requirements
* OZ Defender Relayer 
  * send the transaction
  * relayer must set an allowance of RARE for the staking registry
  * relayer must have RARE balance to send the RARE
* OZ Defender Sentinel
  * to trigger the autotask
  * The following are events the Sentinel should monitor
  * 
  ```
  AcceptOffer(address,address,address,address,uint256,uint256,address[],uint8[])
  AuctionSettled(address,address,address,uint256,address,uint256)
  Sold(address,address,address,address,uint256,uint256)
  ```
* API Key for coinmarketcap

See the `secrets` in the code to find the necessary environment variables.