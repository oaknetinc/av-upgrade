// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AdminControl } from "./AdminControl.sol";
import { CircuitBreaker } from "./modules/CircuitBreaker.sol";
import { InvariantRegistry } from "./modules/InvariantRegistry.sol";
import { RateLimiter } from "./modules/RateLimiter.sol";

contract AVGuard is AdminControl {
    error TargetNotEnabled(address target);

    CircuitBreaker public immutable circuitBreaker;
    InvariantRegistry public immutable invariantRegistry;
    RateLimiter public immutable rateLimiter;

    mapping(address => bool) public enabledTarget;

    event TargetEnabled(address indexed target, bool enabled);
    event CheckPassed(address indexed target, bytes4 indexed selector, uint256 outflow);

    constructor(
        address initialAdmin,
        CircuitBreaker breaker,
        InvariantRegistry registry,
        RateLimiter limiter
    ) AdminControl(initialAdmin) {
        _requireContract(address(breaker));
        _requireContract(address(registry));
        _requireContract(address(limiter));
        circuitBreaker = breaker;
        invariantRegistry = registry;
        rateLimiter = limiter;
    }

    function setTarget(address target, bool enabled) external onlyAdmin {
        if (target == address(0)) revert ZeroAddress();
        if (enabled) _requireContract(target);
        enabledTarget[target] = enabled;
        emit TargetEnabled(target, enabled);
    }

    function check(bytes4 selector, uint256 outflow, bytes calldata context) external {
        address target = msg.sender;
        if (!enabledTarget[target]) revert TargetNotEnabled(target);

        circuitBreaker.requireOperational(target);
        invariantRegistry.validate(target, selector, context);
        rateLimiter.consume(target, selector, outflow);

        emit CheckPassed(target, selector, outflow);
    }
}
