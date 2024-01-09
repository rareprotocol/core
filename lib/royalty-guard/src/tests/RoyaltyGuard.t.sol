// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {IRoyaltyGuard, RoyaltyGuard} from "../royalty-guard/RoyaltyGuard.sol";

contract RoyaltyGuardOwner is RoyaltyGuard {
  address public owner;

  constructor(address _owner, IRoyaltyGuard.ListType _listType, address[] memory _addrs) {
    owner = _owner;
    _setListType(_listType);
    _batchUpdateList(_listType, _addrs, true);
  }

  function hasAdminPermission(address _addr) public view override returns (bool) {
    return _addr == owner;
  }

  function testCheckList(address _addr) external checkList(_addr) {}
}

contract RoyaltyGuardTest is Test {
  RoyaltyGuardOwner guard;
  address alice;
  address bob;
  address charlie;
  uint256 deployDatetime;

  function setUp() public {
    alice = address(0x1337);
    bob = address(0xBEEF);
    charlie = address(0xCAFE);

    address[] memory allowList = new address[](1);
    allowList[0] = bob;

    guard = new RoyaltyGuardOwner(alice, IRoyaltyGuard.ListType.ALLOW, allowList);

    deployDatetime = block.timestamp;
  }

  function testGetListType() public view {
    IRoyaltyGuard.ListType listType = guard.getListType();
    assert(listType == IRoyaltyGuard.ListType.ALLOW);
  }

  function testListValues() public view {
    address[] memory addrs = guard.getInUseList();
    assert(addrs.length == 1);
    assert(addrs[0] == bob);
  }

  function testCheckList_ALLOW(address _addr) public {
    if (_addr != bob) {
      vm.expectRevert(IRoyaltyGuard.Unauthorized.selector);
    }

    guard.testCheckList(_addr);

    address[] memory addrs = new address[](1);
    addrs[0] = _addr;

    vm.prank(alice);
    guard.batchAddAddressToRoyaltyList(IRoyaltyGuard.ListType.ALLOW, addrs);

    guard.testCheckList(_addr);
  }

  function testCheckList_DENY(address _addr) public {
    address[] memory denyList = new address[](1);
    denyList[0] = bob;

    guard = new RoyaltyGuardOwner(alice, IRoyaltyGuard.ListType.DENY, denyList);

    if (_addr == bob) {
      vm.expectRevert(IRoyaltyGuard.Unauthorized.selector);
    }

    guard.testCheckList(_addr);

    address[] memory addrs = new address[](1);
    addrs[0] = _addr;

    vm.prank(alice);
    guard.batchAddAddressToRoyaltyList(IRoyaltyGuard.ListType.DENY, addrs);

    vm.expectRevert(IRoyaltyGuard.Unauthorized.selector);
    guard.testCheckList(_addr);
  }

  function testAdminFunctions() public {
    address[] memory addrs = new address[](1);
    addrs[0] = charlie;

    vm.startPrank(alice);
    guard.toggleListType(IRoyaltyGuard.ListType.DENY);
    guard.batchAddAddressToRoyaltyList(IRoyaltyGuard.ListType.DENY, addrs);
    guard.batchRemoveAddressToRoyaltyList(IRoyaltyGuard.ListType.DENY, addrs);
    guard.clearList(IRoyaltyGuard.ListType.DENY);
    vm.stopPrank();

    vm.startPrank(bob);
    vm.expectRevert(IRoyaltyGuard.MustBeAdmin.selector);
    guard.toggleListType(IRoyaltyGuard.ListType.DENY);
    vm.expectRevert(IRoyaltyGuard.MustBeAdmin.selector);
    guard.batchAddAddressToRoyaltyList(IRoyaltyGuard.ListType.DENY, addrs);
    vm.expectRevert(IRoyaltyGuard.MustBeAdmin.selector);
    guard.batchRemoveAddressToRoyaltyList(IRoyaltyGuard.ListType.DENY, addrs);
    vm.expectRevert(IRoyaltyGuard.MustBeAdmin.selector);
    guard.clearList(IRoyaltyGuard.ListType.DENY);
    vm.stopPrank();
  }
}
