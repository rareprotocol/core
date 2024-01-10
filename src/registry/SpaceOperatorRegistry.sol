// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {AccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ISpaceOperatorRegistry} from "./interfaces/ISpaceOperatorRegistry.sol";

contract SpaceOperatorRegistry is
    ISpaceOperatorRegistry,
    AccessControlUpgradeable
{
    bytes32 public constant SPACE_OPERATOR_REGISTER_ROLE =
        keccak256("SPACE_OPERATOR_REGISTER_ROLE");

    event SpaceOperatorApproved(
        address indexed _operator,
        address indexed _approver,
        bool _approved
    );

    mapping(address => bool) public isApprovedOperator;

    function initialize() public initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender);
    }

    function getPlatformCommission(address)
        external
        pure
        override
        returns (uint8)
    {
        return 5;
    }

    function setPlatformCommission(address, uint8) external override {}

    function isApprovedSpaceOperator(address _operator)
        external
        view
        override
        returns (bool)
    {
        return isApprovedOperator[_operator];
    }

    function setSpaceOperatorApproved(address _operator, bool _approved)
        external
        override
    {
        require(hasRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender));
        isApprovedOperator[_operator] = _approved;
        emit SpaceOperatorApproved(_operator, msg.sender, _approved);
    }

    function batchSetSpaceOperatorApproved(
        address[] calldata _operators,
        bool _approved
    ) external {
        for (uint256 i = 0; i < _operators.length; i++) {
            require(hasRole(SPACE_OPERATOR_REGISTER_ROLE, msg.sender));
            isApprovedOperator[_operators[i]] = _approved;
            emit SpaceOperatorApproved(_operators[i], msg.sender, _approved);
        }
    }
}
