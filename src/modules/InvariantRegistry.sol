// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AdminControl } from "../AdminControl.sol";
import { IAVInvariant } from "../interfaces/IAVInvariant.sol";

contract InvariantRegistry is AdminControl {
    error TooManyInvariants();
    error InvariantRejected(address invariant, bytes32 reason);

    uint256 public constant MAX_INVARIANTS = 8;
    mapping(bytes32 => address[]) private _invariants;

    event InvariantAdded(address indexed target, bytes4 indexed selector, address invariant);
    event InvariantsCleared(address indexed target, bytes4 indexed selector);

    constructor(address initialAdmin) AdminControl(initialAdmin) { }

    function addInvariant(address target, bytes4 selector, address invariant) external onlyAdmin {
        if (invariant == address(0)) revert ZeroAddress();
        _requireContract(target);
        _requireContract(invariant);
        address[] storage entries = _invariants[_key(target, selector)];
        if (entries.length >= MAX_INVARIANTS) revert TooManyInvariants();
        entries.push(invariant);
        emit InvariantAdded(target, selector, invariant);
    }

    function clearInvariants(address target, bytes4 selector) external onlyAdmin {
        delete _invariants[_key(target, selector)];
        emit InvariantsCleared(target, selector);
    }

    function getInvariants(address target, bytes4 selector)
        external
        view
        returns (address[] memory)
    {
        return _invariants[_key(target, selector)];
    }

    function validate(address target, bytes4 selector, bytes calldata context) external view {
        address[] storage entries = _invariants[_key(target, selector)];
        for (uint256 i; i < entries.length; ++i) {
            (bool valid, bytes32 reason) =
                IAVInvariant(entries[i]).validate(target, selector, context);
            if (!valid) revert InvariantRejected(entries[i], reason);
        }
    }

    function _key(address target, bytes4 selector) private pure returns (bytes32) {
        return keccak256(abi.encode(target, selector));
    }
}
