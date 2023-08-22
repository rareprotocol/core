// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";

contract SuperFakeNFT is ERC721("Super Fake", "SUPRFKE") {
  address private bazaar;

  constructor(address _bazaar) {
    bazaar = _bazaar;
  }
  
  function mint(address to, uint256 tokenId) external {
    _mint(to, tokenId);
  }

  function transferFrom(address from, address to, uint256 tokenId) public override {
    if (msg.sender == bazaar) {
      return;
    }

    super.transferFrom(from, to, tokenId);
  }
}