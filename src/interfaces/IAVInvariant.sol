// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAVInvariant {
    function validate(address target, bytes4 selector, bytes calldata context)
        external
        view
        returns (bool valid, bytes32 reason);
}

