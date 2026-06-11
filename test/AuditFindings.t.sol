// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AVGuard } from "../src/AVGuard.sol";
import { CircuitBreaker } from "../src/modules/CircuitBreaker.sol";
import { GuardianCouncil } from "../src/modules/GuardianCouncil.sol";
import { InvariantRegistry } from "../src/modules/InvariantRegistry.sol";
import { RateLimiter } from "../src/modules/RateLimiter.sol";
import { VerifiedUpgradeManager } from "../src/modules/VerifiedUpgradeManager.sol";
import {
    SolvencyInvariant,
    WithdrawalAuthorizationInvariant
} from "../src/demo/VaultInvariants.sol";
import { ProtectedVault } from "../src/demo/ProtectedVault.sol";

interface VmAudit {
    function deal(address account, uint256 newBalance) external;
    function prank(address msgSender) external;
    function warp(uint256 newTimestamp) external;
}

contract AuditImplementation { }

contract AuditProxy {
    address public manager;
    address public implementation;

    constructor(address initialManager) {
        manager = initialManager;
    }

    function upgradeToAndCall(address newImplementation, bytes calldata) external payable {
        require(msg.sender == manager, "NOT_MANAGER");
        implementation = newImplementation;
    }
}

contract AuditFindingsTest {
    VmAudit private constant VM = VmAudit(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant VICTIM = address(0xA11CE);
    address private constant ATTACKER = address(0xBAD);
    address private constant NEW_ADMIN = address(0xB0B);
    address private constant GUARDIAN_ONE = address(0x101);
    address private constant GUARDIAN_TWO = address(0x102);

    function testAudit_AdminCanRemoveAuthorizationInvariantAndEnableTheft() public {
        CircuitBreaker breaker = new CircuitBreaker(address(this));
        InvariantRegistry registry = new InvariantRegistry(address(this));
        RateLimiter limiter = new RateLimiter(address(this));
        AVGuard guard = new AVGuard(address(this), breaker, registry, limiter);
        ProtectedVault vault = new ProtectedVault(guard);
        WithdrawalAuthorizationInvariant authorization = new WithdrawalAuthorizationInvariant();
        SolvencyInvariant solvency = new SolvencyInvariant();

        limiter.setGuard(address(guard));
        guard.setTarget(address(vault), true);
        registry.addInvariant(
            address(vault), ProtectedVault.withdrawFrom.selector, address(authorization)
        );
        registry.addInvariant(
            address(vault), ProtectedVault.withdrawFrom.selector, address(solvency)
        );
        limiter.setLimit(
            address(vault), ProtectedVault.withdrawFrom.selector, 1 ether, 5 ether, 1 hours, true
        );

        VM.deal(VICTIM, 1 ether);
        VM.prank(VICTIM);
        vault.deposit{ value: 1 ether }();

        registry.clearInvariants(address(vault), ProtectedVault.withdrawFrom.selector);

        VM.prank(ATTACKER);
        vault.withdrawFrom(VICTIM, 1 ether, payable(ATTACKER));

        require(vault.credit(VICTIM) == 0, "victim credit remains");
        require(ATTACKER.balance == 1 ether, "attacker did not receive funds");
    }

    function testAudit_InitialAdminBypassesGuardianThresholdForPause() public {
        CircuitBreaker breaker = new CircuitBreaker(address(this));
        address[] memory guardians = new address[](2);
        guardians[0] = GUARDIAN_ONE;
        guardians[1] = GUARDIAN_TWO;
        GuardianCouncil council = new GuardianCouncil(address(this), breaker, guardians, 2);
        breaker.setPauser(address(council), true);

        address target = address(new AuditImplementation());
        breaker.pause(target, keccak256("ADMIN_DIRECT_PAUSE"));

        require(breaker.paused(target), "admin could not pause directly");
        require(council.voteCount(keccak256("unused")) == 0, "unexpected council vote");
    }

    function testAudit_ScheduledUpgradeSurvivesAdminHandoff() public {
        VerifiedUpgradeManager manager = new VerifiedUpgradeManager(address(this), 2 days, 7 days);
        AuditProxy proxy = new AuditProxy(address(manager));
        AuditImplementation implementation = new AuditImplementation();
        bytes memory data;

        uint256 upgradeId = manager.schedule(
            address(proxy), address(implementation), address(implementation).codehash, data
        );
        manager.transferAdmin(NEW_ADMIN);
        VM.prank(NEW_ADMIN);
        manager.acceptAdmin();

        VM.warp(block.timestamp + 2 days);
        VM.prank(ATTACKER);
        manager.execute(upgradeId, data);

        require(proxy.implementation() == address(implementation), "queued upgrade was stopped");
    }
}
