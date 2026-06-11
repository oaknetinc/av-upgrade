// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AVGuard } from "../src/AVGuard.sol";
import { CircuitBreaker } from "../src/modules/CircuitBreaker.sol";
import { GuardianCouncil } from "../src/modules/GuardianCouncil.sol";
import { InvariantRegistry } from "../src/modules/InvariantRegistry.sol";
import { RateLimiter } from "../src/modules/RateLimiter.sol";
import { VerifiedUpgradeManager } from "../src/modules/VerifiedUpgradeManager.sol";
import { ProtectedVault } from "../src/demo/ProtectedVault.sol";
import {
    SolvencyInvariant,
    WithdrawalAuthorizationInvariant
} from "../src/demo/VaultInvariants.sol";

interface VmDeploy {
    enum CallerMode {
        None,
        Broadcast,
        RecurrentBroadcast,
        Prank,
        RecurrentPrank
    }

    function startBroadcast() external;
    function stopBroadcast() external;
    function readCallers()
        external
        returns (CallerMode callerMode, address msgSender, address txOrigin);
}

contract DeployBaseSepolia {
    VmDeploy private constant VM =
        VmDeploy(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint64 private constant UPGRADE_DELAY = 2 days;
    uint64 private constant UPGRADE_GRACE_PERIOD = 7 days;

    struct Deployment {
        CircuitBreaker circuitBreaker;
        InvariantRegistry invariantRegistry;
        RateLimiter rateLimiter;
        AVGuard avGuard;
        GuardianCouncil guardianCouncil;
        VerifiedUpgradeManager upgradeManager;
        ProtectedVault protectedVault;
        WithdrawalAuthorizationInvariant authorizationInvariant;
        SolvencyInvariant solvencyInvariant;
    }

    function run() external returns (Deployment memory deployment) {
        VM.startBroadcast();
        (, address admin,) = VM.readCallers();

        deployment.circuitBreaker = new CircuitBreaker(admin);
        deployment.invariantRegistry = new InvariantRegistry(admin);
        deployment.rateLimiter = new RateLimiter(admin);
        deployment.avGuard = new AVGuard(
            admin, deployment.circuitBreaker, deployment.invariantRegistry, deployment.rateLimiter
        );

        address[] memory guardians = new address[](1);
        guardians[0] = admin;
        deployment.guardianCouncil =
            new GuardianCouncil(admin, deployment.circuitBreaker, guardians, 1);
        deployment.upgradeManager =
            new VerifiedUpgradeManager(admin, UPGRADE_DELAY, UPGRADE_GRACE_PERIOD);

        deployment.protectedVault = new ProtectedVault(deployment.avGuard);
        deployment.authorizationInvariant = new WithdrawalAuthorizationInvariant();
        deployment.solvencyInvariant = new SolvencyInvariant();

        deployment.rateLimiter.setGuard(address(deployment.avGuard));
        deployment.circuitBreaker.setPauser(address(deployment.guardianCouncil), true);
        deployment.avGuard.setTarget(address(deployment.protectedVault), true);

        bytes4 selector = ProtectedVault.withdrawFrom.selector;
        deployment.invariantRegistry
            .addInvariant(
                address(deployment.protectedVault),
                selector,
                address(deployment.authorizationInvariant)
            );
        deployment.invariantRegistry
            .addInvariant(
                address(deployment.protectedVault), selector, address(deployment.solvencyInvariant)
            );
        deployment.rateLimiter
            .setLimit(address(deployment.protectedVault), selector, 1 ether, 5 ether, 1 hours, true);

        VM.stopBroadcast();
    }
}
