// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TestRare is ERC20 {
  constructor() ERC20("Rare", "RARE") {
    _mint(msg.sender, 1_000_000_000 ether);
  }

  function burn(uint256 amount) public {
    _burn(msg.sender, amount);
  }
}