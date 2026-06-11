// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AdminControl } from "../AdminControl.sol";
import { IAVUpgradeable } from "../interfaces/IAVUpgradeable.sol";

contract VerifiedUpgradeManager is AdminControl {
    error UpgradeNotReady();
    error UpgradeExpired();
    error CodeHashMismatch(bytes32 actual, bytes32 expected);
    error UpgradeCallFailed();

    struct Upgrade {
        address proxy;
        address implementation;
        bytes32 expectedCodeHash;
        bytes32 dataHash;
        uint64 executeAfter;
        uint64 expiresAt;
        bool executed;
    }

    uint64 public immutable minimumDelay;
    uint64 public immutable gracePeriod;
    uint256 public nextUpgradeId;
    mapping(uint256 => Upgrade) public upgrades;

    event UpgradeScheduled(
        uint256 indexed upgradeId,
        address indexed proxy,
        address indexed implementation,
        bytes32 expectedCodeHash,
        uint64 executeAfter,
        uint64 expiresAt
    );
    event UpgradeExecuted(uint256 indexed upgradeId);

    constructor(address initialAdmin, uint64 delay, uint64 grace) AdminControl(initialAdmin) {
        require(grace > 0, "ZERO_GRACE");
        minimumDelay = delay;
        gracePeriod = grace;
    }

    function schedule(
        address proxy,
        address implementation,
        bytes32 expectedCodeHash,
        bytes calldata data
    ) external onlyAdmin returns (uint256 upgradeId) {
        if (proxy == address(0) || implementation == address(0)) {
            revert ZeroAddress();
        }
        _requireContract(proxy);
        _requireContract(implementation);
        bytes32 actualCodeHash = implementation.codehash;
        if (actualCodeHash != expectedCodeHash) {
            revert CodeHashMismatch(actualCodeHash, expectedCodeHash);
        }
        uint64 executeAfter = uint64(block.timestamp) + minimumDelay;
        uint64 expiresAt = executeAfter + gracePeriod;
        upgradeId = nextUpgradeId++;
        upgrades[upgradeId] = Upgrade({
            proxy: proxy,
            implementation: implementation,
            expectedCodeHash: expectedCodeHash,
            dataHash: keccak256(data),
            executeAfter: executeAfter,
            expiresAt: expiresAt,
            executed: false
        });
        emit UpgradeScheduled(
            upgradeId, proxy, implementation, expectedCodeHash, executeAfter, expiresAt
        );
    }

    function execute(uint256 upgradeId, bytes calldata data) external payable {
        Upgrade storage upgrade = upgrades[upgradeId];
        if (
            upgrade.executed || block.timestamp < upgrade.executeAfter
                || keccak256(data) != upgrade.dataHash
        ) revert UpgradeNotReady();
        if (block.timestamp > upgrade.expiresAt) revert UpgradeExpired();

        bytes32 actualCodeHash = upgrade.implementation.codehash;
        if (actualCodeHash != upgrade.expectedCodeHash) {
            revert CodeHashMismatch(actualCodeHash, upgrade.expectedCodeHash);
        }

        upgrade.executed = true;
        (bool success,) = upgrade.proxy.call{ value: msg.value }(
            abi.encodeCall(IAVUpgradeable.upgradeToAndCall, (upgrade.implementation, data))
        );
        if (!success) revert UpgradeCallFailed();
        emit UpgradeExecuted(upgradeId);
    }
}
