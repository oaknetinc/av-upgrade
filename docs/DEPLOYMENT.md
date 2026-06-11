# Base Sepolia Deployment

AV Upgrade is intended to reach a public testnet before any production
deployment. The current deployment target is Base Sepolia (`chainId 84532`).

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

The repository expects a local Foundry keystore account named
`payflow-deployer`. Foundry prompts for its password locally; never paste the
password into chat, source control, command history, or an environment file.

```bash
forge script script/DeployBaseSepolia.s.sol:DeployBaseSepolia \
  --rpc-url https://sepolia.base.org \
  --account payflow-deployer \
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

