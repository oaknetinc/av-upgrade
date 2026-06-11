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
    uint256 public councilEpoch;

    mapping(address => bool) public isGuardian;
    mapping(bytes32 => uint256) public voteCount;
    mapping(bytes32 => mapping(address => bool)) public hasVoted;
    mapping(bytes32 => bool) public executed;

    event GuardianSet(address indexed guardian, bool allowed);
    event ThresholdSet(uint256 threshold);
    event CouncilEpochAdvanced(uint256 indexed councilEpoch);
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
        _requireContract(address(breaker));
        circuitBreaker = breaker;
        for (uint256 i; i < initialGuardians.length; ++i) {
            _setGuardian(initialGuardians[i], true);
        }
        _setThreshold(initialThreshold);
        councilEpoch = 1;
        emit CouncilEpochAdvanced(1);
    }

    function setGuardian(address guardian, bool allowed) external onlyAdmin {
        bool changed = isGuardian[guardian] != allowed;
        _setGuardian(guardian, allowed);
        if (threshold > guardianCount) revert InvalidThreshold();
        if (changed) _advanceEpoch();
    }

    function setThreshold(uint256 newThreshold) external onlyAdmin {
        if (newThreshold == threshold) return;
        _setThreshold(newThreshold);
        _advanceEpoch();
    }

    function voteToPause(address target, bytes32 reason, bytes32 salt) external {
        if (!isGuardian[msg.sender]) revert NotGuardian();
        if (target == address(0)) revert ZeroAddress();

        bytes32 incidentId = getIncidentId(target, reason, salt);
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

    function getIncidentId(address target, bytes32 reason, bytes32 salt)
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encode(councilEpoch, target, reason, salt));
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

    function _advanceEpoch() private {
        ++councilEpoch;
        emit CouncilEpochAdvanced(councilEpoch);
    }
}
