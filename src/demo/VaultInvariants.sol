// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { IAVInvariant } from "../interfaces/IAVInvariant.sol";

library VaultContext {
    struct Withdrawal {
        address caller;
        address account;
        uint256 balanceBefore;
        uint256 liabilitiesBefore;
        uint256 amount;
    }
}

contract WithdrawalAuthorizationInvariant is IAVInvariant {
    bytes32 public constant UNAUTHORIZED = keccak256("AV_UNAUTHORIZED_WITHDRAWAL");

    function validate(address, bytes4, bytes calldata context)
        external
        pure
        returns (bool valid, bytes32 reason)
    {
        VaultContext.Withdrawal memory withdrawal = abi.decode(context, (VaultContext.Withdrawal));
        valid = withdrawal.caller == withdrawal.account;
        reason = valid ? bytes32(0) : UNAUTHORIZED;
    }
}

contract SolvencyInvariant is IAVInvariant {
    bytes32 public constant INSOLVENT = keccak256("AV_INSOLVENT_AFTER_WITHDRAWAL");

    function validate(address, bytes4, bytes calldata context)
        external
        pure
        returns (bool valid, bytes32 reason)
    {
        VaultContext.Withdrawal memory withdrawal = abi.decode(context, (VaultContext.Withdrawal));
        if (
            withdrawal.amount > withdrawal.balanceBefore
                || withdrawal.amount > withdrawal.liabilitiesBefore
        ) {
            return (false, INSOLVENT);
        }

        uint256 balanceAfter = withdrawal.balanceBefore - withdrawal.amount;
        uint256 liabilitiesAfter = withdrawal.liabilitiesBefore - withdrawal.amount;
        valid = balanceAfter >= liabilitiesAfter;
        reason = valid ? bytes32(0) : INSOLVENT;
    }
}

