// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AdminControl } from "../AdminControl.sol";

contract CircuitBreaker is AdminControl {
    error NotPauser();
    error TargetPaused(address target);

    mapping(address => bool) public isPauser;
    mapping(address => bool) public paused;
    mapping(address => bytes32) public pauseReason;

    event PauserSet(address indexed account, bool allowed);
    event TargetPausedEvent(address indexed target, address indexed pauser, bytes32 reason);
    event TargetUnpaused(address indexed target);

    constructor(address initialAdmin) AdminControl(initialAdmin) {
        isPauser[initialAdmin] = true;
        emit PauserSet(initialAdmin, true);
    }

    function setPauser(address account, bool allowed) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        isPauser[account] = allowed;
        emit PauserSet(account, allowed);
    }

    function pause(address target, bytes32 reason) external {
        if (!isPauser[msg.sender]) revert NotPauser();
        paused[target] = true;
        pauseReason[target] = reason;
        emit TargetPausedEvent(target, msg.sender, reason);
    }

    function unpause(address target) external onlyAdmin {
        paused[target] = false;
        pauseReason[target] = bytes32(0);
        emit TargetUnpaused(target);
    }

    function requireOperational(address target) external view {
        if (paused[target]) revert TargetPaused(target);
    }
}

