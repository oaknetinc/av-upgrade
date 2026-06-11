# Base Sepolia Deployment

AV Upgrade is intended to reach a public testnet before any production
deployment. The current deployment target is Base Sepolia (`chainId 84532`).

## Current Deployment

All nine contracts were deployed on June 11, 2026 and received Sourcify
`exact_match` source verification.

| Contract | Address |
| --- | --- |
| CircuitBreaker | [`0xF047...6A64`](https://sepolia.basescan.org/address/0xF047FF27C4B22b2527636cf62bc31490665d6A64) |
| InvariantRegistry | [`0x5993...6Af3`](https://sepolia.basescan.org/address/0x59937BDd6a817Cc8d025e9e4B1cc03e37d796Af3) |
| RateLimiter | [`0x6e9f...1A6e`](https://sepolia.basescan.org/address/0x6e9fbd22529B048df40A667b5EC27e04A3011A6e) |
| AVGuard | [`0x0FE7...72f5`](https://sepolia.basescan.org/address/0x0FE70Ba49887D1469b674dF9Eb30c8f8ffF972f5) |
| GuardianCouncil | [`0xC9C0...113E`](https://sepolia.basescan.org/address/0xC9C07997344B028FE7F82D60e945976628A6113E) |
| VerifiedUpgradeManager | [`0xa17c...487F`](https://sepolia.basescan.org/address/0xa17cc312295D442c8b70DD7977eB159fBCd9487F) |
| ProtectedVault | [`0xF9DC...3E81`](https://sepolia.basescan.org/address/0xF9DCc63F9563C3cf7c1c10c0cA12b5F4b6bc3E81) |
| WithdrawalAuthorizationInvariant | [`0x40c0...aB72`](https://sepolia.basescan.org/address/0x40c0AcF0dCB567cf12EDb3f691C359B95F78aB72) |
| SolvencyInvariant | [`0xA702...968c`](https://sepolia.basescan.org/address/0xA7027A8A161FA5A454B3dDa384B0dc981Cd7968c) |

The machine-readable deployment manifest is
[`deployments/base-sepolia.json`](../deployments/base-sepolia.json).

## Deployed Components

The deployment script creates and configures:

1. `CircuitBreaker`
2. `InvariantRegistry`
3. `RateLimiter`
4. `AVGuard`
5. `GuardianCouncil`
6. `VerifiedUpgradeManager`
7. `ProtectedVault`
8. `WithdrawalAuthorizationInvariant`
9. `SolvencyInvariant`

`VulnerableVault` is intentionally excluded because it contains a deliberate
authorization vulnerability used only by the test suite.

The initial deployer is the admin and sole guardian. This is acceptable for a
testnet demonstration only. A production design must use separate multisigs,
multiple guardians, and delayed administration.

## Validate

```bash
forge fmt --check
forge test --offline
forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia \
  --rpc-url https://sepolia.base.org \
  --sig "run()" \
  -vvv
```

## Broadcast And Verify Sources

The deployment machine has a local Foundry keystore account named
`av-upgrade-deployer`. Its generated password is stored in an owner-only file
outside the repository. Never paste the password into chat, source control,
command history, or a project environment file.

```bash
forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia \
  --rpc-url https://sepolia.base.org \
  --account av-upgrade-deployer \
  --password-file ~/.foundry/keystores/av-upgrade-deployer.password \
  --broadcast \
  --verify \
  --verifier sourcify \
  --sig "run()" \
  -vvv
```

After confirmation, copy the addresses and transaction hashes from:

```text
broadcast/DeployBaseSepolia.s.sol/84532/run-latest.json
```

Do not use addresses from a dry-run artifact. Simulated addresses depend on
the simulated sender nonce and are not proof of deployment.
