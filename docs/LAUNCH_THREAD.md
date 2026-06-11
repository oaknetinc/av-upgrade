# Draft X Launch Thread

## Post 1

AI is making vulnerability discovery faster. DeFi defense has to move beyond
"audit, deploy, and hope."

Today we are open-sourcing AV Upgrade: an experimental runtime containment layer
for EVM protocols.

Code: `<GITHUB_URL>`

## Post 2

AV means Auto-Verify Upgrade.

It lets an integrated protocol enforce deterministic safety rules before a
sensitive transaction commits:

- protocol-specific invariants
- per-transaction outflow limits
- rolling-window limits
- emergency circuit breakers
- threshold guardian pauses
- code-hash-bound delayed upgrades

## Post 3

Important: AV is not a magic "detect every hacker" contract.

Contracts cannot inherently know intent. AV blocks behavior that violates
explicit policies and limits the damage an unknown exploit can cause.

That distinction matters.

## Post 4

The proof of concept includes a vault with a deliberate authorization bug.

The unprotected vault is drained in the test suite.

The same exploit against the AV-integrated vault reverts, while legitimate
withdrawals still work.

## Post 5

AV also separates two jobs that the EVM cannot perform in one reverting
transaction:

1. Reject the dangerous call now.
2. Persist a pause through a separate guardian transaction.

If the exploit transaction reverts, any pause it tried to write would revert
too.

## Post 6

This is version 0.1.0: unaudited, experimental, and not ready for production
funds.

We are publishing early because security infrastructure improves through
adversarial review.

Break it. Challenge the assumptions. Help define better invariants.

## Single-Post Alternative

We are open-sourcing AV Upgrade, an experimental runtime defense layer for EVM
protocols. It combines deterministic invariants, outflow limits, circuit
breakers, guardian pauses, and code-hash-bound upgrades to contain detectable
exploits. It is unaudited and not production-ready. `<GITHUB_URL>`

