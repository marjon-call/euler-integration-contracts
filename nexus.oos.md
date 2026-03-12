# Out of Scope

## Known Issues / Accepted Risks

- **Solver surplus extraction within bond limits:** Solvers can theoretically take all surplus from a user's trade. The CoW Protocol off-chain auction selects the best rate, but this is not enforced on-chain. Slashing bond provides economic deterrent.
- **Solver executing order without wrapper (or wrapper without order):** A solver could execute the CoW order without calling the wrapper, or call the wrapper without executing the user's order. Mitigated by solver rules enforced off-chain with slashing penalties.
- **Anyone can call `EVC.batch()`:** By design, checking `msg.sender == address(EVC)` alone does not provide security. Real security comes from user authorization (permit/pre-approved hash).
- **Frontend receiver misconfiguration:** If a frontend sets the wrong `receiver` address in the CoW order, funds may go to an inaccessible address. This is an integrator responsibility, not a contract vulnerability.
- **Interest accumulation on close position:** Debt accrues interest between order submission and execution. If `buyAmount` buffer is too small, the position may not fully close, leaving dust debt. This is documented and expected behavior.
- **Concurrent close operations on same subaccount:** Submitting multiple close operations for the same subaccount simultaneously is unsupported and may cause unexpected behavior. Users must wait for previous operations to settle or expire.

## In-Scope Impacts (Smart Contracts Only)

Only the following attack impacts are eligible:

**Critical:**
- Direct theft of user funds (collateral, borrowed assets, or vault tokens)
- Permanent freezing of funds in wrappers, Inbox contracts, or EVC subaccounts
- Bypassing user authorization to execute unauthorized operations
- Creating undercollateralized positions that survive EVC health checks

**High:**
- Replay of consumed pre-approved hashes or permit signatures
- Unauthorized access to Inbox funds by non-operator/non-beneficiary
- Breaking atomicity guarantees (partial execution leaving inconsistent state)

**Medium:**
- Per Immunefi Primacy of Impact framework

## Out of Scope: Everything Else

Any impact or vulnerability type not listed above is out of scope, including but not limited to:

- Governance / centralization / admin key risks (trusted roles)
- Third-party / external protocol issues (Ethereum Vault Connector, CoW Protocol Settlement, Euler Vault Kit, OpenZeppelin)
- Flawed assumptions about behavior of external contracts (EVC, Settlement Contract, Euler Vaults) are explicitly out of scope per project documentation
- Solver misbehavior within slashing bond limits (trusted actor assumption)
- Denial of service without fund impact
- Gas optimization issues
- Informational / best practice findings
- Front-running / sandwich attacks that don't result in direct fund theft
- Issues requiring access to privileged roles (CoW allow list manager, solver)
- Vulnerabilities only exploitable on testnets or requiring mainnet state manipulation beyond forking
- Issues arising from incorrect off-chain order construction by integrators

## Program Rules

- PoC required for all severities
- Testing on local forks only (no mainnet/testnet interaction)
- Non-upgradeable contracts: cumulative impact considered
