# AV Upgrade Internal Security Review

Date: June 11, 2026

Commit reviewed: `9b59ed3`

Reviewer: OpenAI Codex, internal review

## Disclaimer

This is an internal engineering review, not an independent professional audit.
It does not certify the contracts as safe. The Base Sepolia and Base mainnet
deployments remain unaudited research deployments and should not custody
production funds.

## Scope

- `src/AVGuard.sol`
- `src/AdminControl.sol`
- `src/interfaces/`
- `src/modules/`
- `src/demo/ProtectedVault.sol`
- `src/demo/VaultInvariants.sol`
- Deployment configuration and administrative topology

`VulnerableVault.sol` was reviewed only as an intentionally vulnerable test
fixture.

## Method

- Manual review of authorization, state transitions, external calls, upgrade
  execution, pausing, guardian voting, invariant evaluation, and rate limiting
- Foundry compilation, size analysis, execution traces, and regression tests
- Proof-of-concept tests in `test/AuditFindings.t.sol`
- Direct read-back of deployed Base mainnet configuration

No external Solidity static analyzer was installed in the review environment.
Foundry lint reported style and gas notes but no high-severity diagnostic.

## Summary

| ID | Severity | Finding | Status |
| --- | --- | --- | --- |
| AV-01 | High | Single admin can remove the vault authorization defense immediately | Open |
| AV-02 | Medium | Scheduled upgrades cannot be cancelled | Open |
| AV-03 | Low | Deployment admin bypasses GuardianCouncil threshold for pausing | Open |
| AV-04 | Informational | Security depends on honest target-supplied context and outflow | By design |
| AV-05 | Informational | Mainnet deployment is centrally administered | Acknowledged |

## AV-01: Admin Can Remove Authorization Defense

Severity: High

### Description

`ProtectedVault.withdrawFrom` deliberately omits an inline ownership check and
depends on `WithdrawalAuthorizationInvariant`. The `InvariantRegistry` admin can
call `clearInvariants` immediately, without a timelock or replacement
requirement.

After the authorization invariant is cleared, any caller can withdraw another
account's credit. The configured limiter reduces extraction speed but does not
prevent theft.

The Base mainnet deployment assigns the registry admin to one encrypted EOA.

### Impact

Compromise or misuse of the admin key can turn the demonstration vault's known
authorization bug back on. Deposited funds can then be stolen within configured
rate limits.

### Proof

`testAudit_AdminCanRemoveAuthorizationInvariantAndEnableTheft`

### Recommendation

- Do not deposit funds into `ProtectedVault`.
- Implement authorization directly in the protected protocol.
- Treat AV invariants as defense in depth, never the sole authorization layer.
- Put invariant changes behind a multisig and timelock.
- Require a minimum policy set or delayed two-step policy replacement.

## AV-02: Scheduled Upgrades Cannot Be Cancelled

Severity: Medium

### Description

`VerifiedUpgradeManager` has `schedule` and `execute` but no cancellation
function. Execution is permissionless after the delay.

If an attacker briefly compromises the admin and schedules a malicious upgrade,
recovering the admin role before the delay expires does not neutralize that
queued operation. Any account can execute it when the delay ends.

### Impact

An otherwise recovered governance compromise can remain exploitable until the
queued upgrade expires or the target proxy independently revokes the manager.

### Proof

`testAudit_ScheduledUpgradeSurvivesAdminHandoff`

### Recommendation

Add an admin or governance-controlled `cancel(upgradeId)` path, emit a
cancellation event, and test cancellation before and after execution. For
production, separate proposer and canceller roles.

## AV-03: Admin Bypasses Guardian Threshold

Severity: Low

### Description

`CircuitBreaker` makes its initial admin a pauser in the constructor. The
deployment then adds `GuardianCouncil` as another pauser but does not revoke the
admin's direct pauser permission.

The configured GuardianCouncil threshold is therefore not required for a pause;
the deployer can pause a target alone.

### Impact

A compromised admin can cause protocol denial of service without guardian
consensus. This does not directly enable theft because unpausing is already an
admin action.

### Proof

`testAudit_InitialAdminBypassesGuardianThresholdForPause`

### Recommendation

After configuring the council, revoke the deployer's pauser role. Use distinct
multisigs for routine administration, emergency pausing, and unpausing.

## AV-04: Target-Supplied Security Inputs

Severity: Informational

`AVGuard.check` trusts the integrated target to supply `selector`, `outflow`,
and encoded invariant context. This is necessary for a generic framework, but
AV cannot detect a target that supplies incomplete or dishonest values.

Each integration must be reviewed to prove that every sensitive path calls AV
with values derived from authoritative protocol state.

## AV-05: Centralized Mainnet Administration

Severity: Informational

One EOA is currently:

- admin of every module;
- the sole guardian with threshold one;
- a direct circuit-breaker pauser;
- the upgrade proposer.

This is acceptable only for a research deployment. It is not a production
governance model.

## Positive Observations

- Dangerous calls fail closed when AV modules or invariants revert.
- Rate-limit state rolls back if the protected operation later reverts.
- Guardian membership and threshold changes invalidate stale votes by epoch.
- Upgrade bytecode and initialization calldata are hash-bound.
- Upgrade execution marks state before the external proxy call.
- Contract dependencies reject EOAs.
- The demo withdrawal follows checks-effects-interactions.
- All deployed contracts received Sourcify exact-match verification.

## Test Results

- 14 tests passed
- 0 failed
- 3 tests are proof-of-concept reproductions of the open findings

Passing proof tests confirm that the documented vulnerable behavior is
reproducible; they do not indicate that the findings are fixed.

## Conclusion

The framework is useful as a research prototype for deterministic containment,
but the current mainnet deployment is not safe for production custody. The
highest-priority action is to prevent invariants from being the only
authorization mechanism and to move all administrative powers from the single
EOA to delayed, role-separated multisigs.
