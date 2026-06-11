// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AVGuard } from "../src/AVGuard.sol";
import { CircuitBreaker } from "../src/modules/CircuitBreaker.sol";
import { GuardianCouncil } from "../src/modules/GuardianCouncil.sol";
import { InvariantRegistry } from "../src/modules/InvariantRegistry.sol";
import { RateLimiter } from "../src/modules/RateLimiter.sol";
import {
    SolvencyInvariant,
    WithdrawalAuthorizationInvariant
} from "../src/demo/VaultInvariants.sol";
import { ProtectedVault } from "../src/demo/ProtectedVault.sol";
import { VulnerableVault } from "../src/demo/VulnerableVault.sol";

interface Vm {
    function deal(address account, uint256 newBalance) external;
    function prank(address msgSender) external;
    function expectRevert() external;
}

contract AVUpgradeTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    address private constant ALICE = address(0xA11CE);
    address private constant ATTACKER = address(0xBAD);
    address private constant GUARDIAN_ONE = address(0x101);
    address private constant GUARDIAN_TWO = address(0x102);

    CircuitBreaker private breaker;
    InvariantRegistry private registry;
    RateLimiter private limiter;
    AVGuard private guard;
    ProtectedVault private protectedVault;
    VulnerableVault private vulnerableVault;

    function setUp() public {
        breaker = new CircuitBreaker(address(this));
        registry = new InvariantRegistry(address(this));
        limiter = new RateLimiter(address(this));
        guard = new AVGuard(address(this), breaker, registry, limiter);
        limiter.setGuard(address(guard));

        protectedVault = new ProtectedVault(guard);
        vulnerableVault = new VulnerableVault();
        guard.setTarget(address(protectedVault), true);

        WithdrawalAuthorizationInvariant authorization = new WithdrawalAuthorizationInvariant();
        SolvencyInvariant solvency = new SolvencyInvariant();
        bytes4 selector = ProtectedVault.withdrawFrom.selector;
        registry.addInvariant(address(protectedVault), selector, address(authorization));
        registry.addInvariant(address(protectedVault), selector, address(solvency));
        limiter.setLimit(address(protectedVault), selector, 5 ether, 8 ether, 1 hours, true);

        vm.deal(ALICE, 20 ether);
        vm.deal(ATTACKER, 1 ether);
        vm.prank(ALICE);
        protectedVault.deposit{ value: 10 ether }();
        vm.prank(ALICE);
        vulnerableVault.deposit{ value: 10 ether }();
    }

    function testUnprotectedVaultCanBeExploited() public {
        uint256 attackerBefore = ATTACKER.balance;
        vm.prank(ATTACKER);
        vulnerableVault.withdrawFrom(ALICE, 10 ether, payable(ATTACKER));

        require(ATTACKER.balance == attackerBefore + 10 ether, "exploit did not pay attacker");
        require(vulnerableVault.credit(ALICE) == 0, "victim credit remains");
    }

    function testAVBlocksUnauthorizedWithdrawal() public {
        uint256 attackerBefore = ATTACKER.balance;
        vm.prank(ATTACKER);
        vm.expectRevert();
        protectedVault.withdrawFrom(ALICE, 5 ether, payable(ATTACKER));

        require(ATTACKER.balance == attackerBefore, "attacker received funds");
        require(protectedVault.credit(ALICE) == 10 ether, "victim credit changed");
    }

    function testAVAllowsAuthorizedWithdrawal() public {
        uint256 aliceBefore = ALICE.balance;
        vm.prank(ALICE);
        protectedVault.withdrawFrom(ALICE, 4 ether, payable(ALICE));

        require(ALICE.balance == aliceBefore + 4 ether, "alice did not receive withdrawal");
        require(protectedVault.credit(ALICE) == 6 ether, "credit not updated");
    }

    function testRateLimitContainsLargeOutflow() public {
        vm.prank(ALICE);
        vm.expectRevert();
        protectedVault.withdrawFrom(ALICE, 6 ether, payable(ALICE));
        require(protectedVault.credit(ALICE) == 10 ether, "credit changed after limited call");
    }

    function testGuardianThresholdPausesTarget() public {
        address[] memory guardians = new address[](2);
        guardians[0] = GUARDIAN_ONE;
        guardians[1] = GUARDIAN_TWO;
        GuardianCouncil council = new GuardianCouncil(address(this), breaker, guardians, 2);
        breaker.setPauser(address(council), true);

        bytes32 reason = keccak256("ACTIVE_EXPLOIT");
        bytes32 salt = keccak256("incident-1");
        vm.prank(GUARDIAN_ONE);
        council.voteToPause(address(protectedVault), reason, salt);
        require(!breaker.paused(address(protectedVault)), "paused before threshold");

        vm.prank(GUARDIAN_TWO);
        council.voteToPause(address(protectedVault), reason, salt);
        require(breaker.paused(address(protectedVault)), "target not paused");

        vm.prank(ALICE);
        vm.expectRevert();
        protectedVault.withdrawFrom(ALICE, 1 ether, payable(ALICE));
    }
}

