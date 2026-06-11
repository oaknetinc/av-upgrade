// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AdminControl } from "../AdminControl.sol";

contract RateLimiter is AdminControl {
    error NotGuard();
    error TransactionLimitExceeded(uint256 requested, uint256 maximum);
    error WindowLimitExceeded(uint256 requestedTotal, uint256 maximum);

    struct Limit {
        uint128 maxPerTransaction;
        uint128 maxPerWindow;
        uint64 windowDuration;
        bool enabled;
    }

    struct Usage {
        uint128 amount;
        uint64 windowStartedAt;
    }

    address public guard;
    mapping(bytes32 => Limit) public limits;
    mapping(bytes32 => Usage) public usage;

    event GuardSet(address indexed guard);
    event LimitSet(
        address indexed target,
        bytes4 indexed selector,
        uint128 maxPerTransaction,
        uint128 maxPerWindow,
        uint64 windowDuration,
        bool enabled
    );

    constructor(address initialAdmin) AdminControl(initialAdmin) { }

    function setGuard(address newGuard) external onlyAdmin {
        if (newGuard == address(0)) revert ZeroAddress();
        guard = newGuard;
        emit GuardSet(newGuard);
    }

    function setLimit(
        address target,
        bytes4 selector,
        uint128 maxPerTransaction,
        uint128 maxPerWindow,
        uint64 windowDuration,
        bool enabled
    ) external onlyAdmin {
        require(
            !enabled
                || (maxPerTransaction > 0
                    && maxPerWindow >= maxPerTransaction
                    && windowDuration > 0),
            "INVALID_LIMIT"
        );
        limits[_key(target, selector)] =
            Limit(maxPerTransaction, maxPerWindow, windowDuration, enabled);
        emit LimitSet(target, selector, maxPerTransaction, maxPerWindow, windowDuration, enabled);
    }

    function consume(address target, bytes4 selector, uint256 amount) external {
        if (msg.sender != guard) revert NotGuard();

        bytes32 key = _key(target, selector);
        Limit memory limit = limits[key];
        if (!limit.enabled) return;
        if (amount > limit.maxPerTransaction) {
            revert TransactionLimitExceeded(amount, limit.maxPerTransaction);
        }

        Usage memory current = usage[key];
        if (
            current.windowStartedAt == 0
                || block.timestamp >= uint256(current.windowStartedAt) + limit.windowDuration
        ) {
            current.windowStartedAt = uint64(block.timestamp);
            current.amount = 0;
        }

        uint256 nextAmount = uint256(current.amount) + amount;
        if (nextAmount > limit.maxPerWindow) {
            revert WindowLimitExceeded(nextAmount, limit.maxPerWindow);
        }
        // maxPerWindow is uint128, so the comparison above proves this cast is safe.
        // forge-lint: disable-next-line(unsafe-typecast)
        current.amount = uint128(nextAmount);
        usage[key] = current;
    }

    function _key(address target, bytes4 selector) private pure returns (bytes32) {
        return keccak256(abi.encode(target, selector));
    }
}
