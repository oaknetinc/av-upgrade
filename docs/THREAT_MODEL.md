# Threat Model

## Objective

AV Upgrade aims to reduce the blast radius of an exploit by rejecting
policy-breaking calls, limiting rapid outflows, and enabling a persistent
threshold-controlled pause.

It is a containment framework, not a universal exploit detector.

## Protected Assets

- Native assets and tokens held by an integrated protocol
- Internal accounting and solvency
- Availability of sensitive protocol functions
- Integrity of implementation upgrades

## Adversaries

- An unprivileged caller exploiting a contract bug
- A bot executing an AI-discovered vulnerability
- A compromised or malicious guardian
- A compromised upgrade proposer
- A caller attempting to drain value across many transactions

## Security Assumptions

- Protected functions call `AVGuard.check` before irreversible interactions.
- Registered invariants correctly model the intended safety properties.
- Outflow values passed to the limiter reflect economic exposure.
- The breaker, registry, limiter, and guard admins use secure governance.
- Enough guardians remain honest to meet the configured threshold.
- The chain continues producing blocks and is not deeply reorganized.
- Any oracle used by a future invariant is manipulation-resistant and fresh.

## Guarantees Under Those Assumptions

- A configured invariant violation reverts atomically.
- A configured outflow excess reverts atomically.
- A paused target cannot pass the AV check.
- A single guardian cannot pause when the threshold is greater than one.
- A scheduled upgrade cannot substitute different bytecode or calldata.

## Known Limitations

### Unknown behavior

An exploit that preserves every configured invariant and remains below every
limit can pass. Policies are only as complete as their specification.

### Integration bypass

An unguarded function, delegatecall path, fallback, or alternate asset exit can
bypass AV. Integration review must map the full attack surface.

### False positives and liveness

Strict policies may stop legitimate activity during volatility or unusual
market conditions. Limits and invariants need scenario and fuzz testing.

### Guardian response time

Guardian voting does not stop the first transaction. The current exploit must be
rejected by an invariant or limit; guardians persist the pause for later calls.

### Governance compromise

The prototype admin can replace policies, unpause targets, and configure
modules. Production deployments need role separation, multisigs, timelocks, and
on-chain monitoring.

### Upgrade verification

Matching a code hash proves that executed bytecode equals scheduled bytecode. It
does not prove that the implementation is correct, audited, or storage-safe.

### Token behavior

The demo uses native ETH. Fee-on-transfer, rebasing, callback-capable, and
non-standard tokens require token-aware accounting invariants.

## Recommended Production Hardening

- Independent audits of the framework and each integration
- Stateful fuzzing and invariant testing
- Role-separated governance and emergency councils
- Delayed admin changes and transparent policy updates
- Multiple independent monitoring providers
- Failover procedures for guardian and RPC outages
- Bounded emergency withdrawals for users
- Formal specifications for solvency and authorization
- Bug bounty and responsible disclosure program

