// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AdminControl } from "../AdminControl.sol";
import { CircuitBreaker } from "./CircuitBreaker.sol";

contract GuardianCouncil is AdminControl {
    error NotGuardian();
    error InvalidThreshold();
    error AlreadyVoted();

    CircuitBreaker public immutable circuitBreaker;
    uint256 public guardianCount;
    uint256 public threshold;

    mapping(address => bool) public isGuardian;
    mapping(bytes32 => uint256) public voteCount;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;
    mapping(bytes32 => bool) public executed;

    event GuardianSet(address indexed guardian, bool allowed);
    event ThresholdSet(uint256 threshold);
    event IncidentVoted(
        bytes32 indexed incidentId, address indexed target, address indexed guardian, uint256 votes
    );
    event IncidentExecuted(bytes32 indexed incidentId, address indexed target);

    constructor(
        address initialAdmin,
        CircuitBreaker breaker,
        address[] memory initialGuardians,
        uint256 initialThreshold
    ) AdminControl(initialAdmin) {
        circuitBreaker = breaker;
        for (uint256 i; i < initialGuardians.length; ++i) {
            _setGuardian(initialGuardians[i], true);
        }
        _setThreshold(initialThreshold);
    }

    function setGuardian(address guardian, bool allowed) external onlyAdmin {
        _setGuardian(guardian, allowed);
        if (threshold > guardianCount) revert InvalidThreshold();
    }

    function setThreshold(uint256 newThreshold) external onlyAdmin {
        _setThreshold(newThreshold);
    }

    function voteToPause(address target, bytes32 reason, bytes32 salt) external {
        if (!isGuardian[msg.sender]) revert NotGuardian();

        bytes32 incidentId = keccak256(abi.encode(target, reason, salt));
        if (hasVoted[incidentId][msg.sender]) revert AlreadyVoted();
        hasVoted[incidentId][msg.sender] = true;
        uint256 votes = ++voteCount[incidentId];
        emit IncidentVoted(incidentId, target, msg.sender, votes);

        if (votes >= threshold && !executed[incidentId]) {
            executed[incidentId] = true;
            circuitBreaker.pause(target, reason);
            emit IncidentExecuted(incidentId, target);
        }
    }

    function _setGuardian(address guardian, bool allowed) private {
        if (guardian == address(0)) revert ZeroAddress();
        if (isGuardian[guardian] == allowed) return;
        isGuardian[guardian] = allowed;
        if (allowed) {
            ++guardianCount;
        } else {
            --guardianCount;
        }
        emit GuardianSet(guardian, allowed);
    }

    function _setThreshold(uint256 newThreshold) private {
        if (newThreshold == 0 || newThreshold > guardianCount) revert InvalidThreshold();
        threshold = newThreshold;
        emit ThresholdSet(newThreshold);
    }
}

