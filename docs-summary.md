# Euler-CoW Protocol Integration: Documentation Summary

## Protocol Overview

This repository contains **Euler-CoW Protocol integration contracts** that enable leveraged position management and collateral swaps through CoW Protocol settlements combined with the Ethereum Vault Connector (EVC). The contracts use CoW's Generalized Wrappers architecture to coordinate complex multi-step DeFi operations atomically.

Full documentation is in `docs/`.

## Architecture

### Wrapper Chain Pattern

Solvers call `wrappedSettle()` on the first wrapper, which processes its logic, then delegates to the next wrapper or the final CoW Settlement contract. Wrappers can be chained: Wrapper1 -> Wrapper2 -> Settlement.

### Contract Hierarchy

```
CowWrapper (base, solver auth, chaining)
  └── CowEvcBaseWrapper (EVC batch coordination, EIP-712 auth)
        ├── CowEvcOpenPositionWrapper   (open/grow leveraged positions)
        ├── CowEvcClosePositionWrapper  (close/reduce positions, uses Inbox)
        └── CowEvcCollateralSwapWrapper (swap collateral between vaults)
```

Supporting contracts:
- **Inbox / InboxFactory** - Per-subaccount contract for ClosePosition; receives swap output, implements EIP-1271 for CoW order signing
- **PreApprovedHashes** - On-chain hash pre-approval (EIP-7702 compatible auth flow)
- **CowWrapperHelpers** - Off-chain validation and wrapper data encoding

## Three Wrappers

### 1. Open Position (`CowEvcOpenPositionWrapper`)
Opens or grows a leveraged long/short position:
1. Enable collateral vault + controller (borrow vault)
2. Deposit collateral
3. Borrow assets
4. CoW settlement swaps borrowed assets -> collateral vault tokens -> deposited to subaccount

**CoW Order**: `sellToken` = borrow vault's underlying, `buyToken` = collateral vault, `sellAmount` = borrowAmount, `receiver` = account, `kind` = "sell"

### 2. Close Position (`CowEvcClosePositionWrapper`)
Closes or reduces a leveraged position:
1. Transfer collateral from subaccount to Inbox
2. CoW settlement swaps collateral -> debt repayment asset (sent to Inbox)
3. Inbox repays debt to borrow vault
4. Excess returned to owner

**CoW Order**: `sellToken` = collateral vault, `buyToken` = borrow vault's underlying asset, `receiver` = Inbox address (from `getInbox(owner, account)`), `kind` = "buy" for full close (exact output), "sell" for partial

**Key difference**: Uses EIP-1271 signature validation through the Inbox contract, not standard EIP-712. The Inbox has its own domain separator.

### 3. Collateral Swap (`CowEvcCollateralSwapWrapper`)
Swaps collateral between vaults while maintaining debt:
1. Enable destination vault as collateral
2. Transfer old collateral from subaccount to owner (if using subaccount)
3. CoW settlement swaps old vault tokens -> new vault tokens
4. New collateral deposited to subaccount

**CoW Order**: `sellToken` = fromVault, `buyToken` = toVault, `sellAmount` = fromAmount, `receiver` = account, `kind` = "sell" only

## Authorization Flows

### Flow 1: EVC Permit (Off-Chain Signature)
- User signs EIP-712 permit via `encodePermitData(params)` + signs CoW order
- Minimal on-chain txs (just token approvals)
- Not compatible with smart contract wallets

### Flow 2: Pre-Approved Hash (On-Chain)
- User calls `setPreApprovedHash(hash, true)` + sets EVC operator + pre-signs CoW order
- Compatible with EIP-7702 wallets (can batch all approvals)
- Hashes are consumed after use (no replay)

## Key Addresses (Ethereum Mainnet)

| Contract | Address | Proxy? |
|----------|---------|--------|
| CoW Settlement | `0x9008D19f58AAbD9eD0D60971565AA8510560ab41` | No |
| CoW Vault Relayer | `0xC92E8bdf79f0507f65a392b0ab4667716BFE0110` | No |
| CoW Authenticator | `0x2c4c28DDBdAc9C5E7055b4C863b72eA0149D8aFE` | Yes |
| EVC | `0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383` | No |
| eUSDS Vault | `0x07F9A54Dc5135B9878d6745E267625BF0E206840` | No |
| eWETH Vault | `0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2` | No |
| eWBTC Vault | `0x998D761eC1BAdaCeb064624cc3A1d37A46C88bA4` | No |
| USDS | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` | Yes |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | No |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | No |
| Allow List Manager | `0xA03be496e67Ec29bC62F01a428683D7F9c204930` | No |

## Security Model

### Trusted Actors
- **Solvers**: Subject to slashing, compete in auction for best execution. Cannot steal funds via clearing prices (bounded by user limit prices). Can skim surplus within bond limits.
- **EVC**: Enforces account health checks at batch end. Audited, in production.
- **CoW Settlement**: Audited, in production for years.

### Critical Security Properties
1. **User Intent Validation** - All params covered by EIP-712 hash; cannot alter without invalidating signature
2. **Atomicity** - EVC batch ensures all-or-nothing execution
3. **Reentrancy Protection** - Transient storage hash check on `evcInternalSettle` callback
4. **Account Health** - EVC enforces collateralization ratio at batch conclusion; undercollateralized positions revert
5. **Replay Prevention** - Unique deadline per operation + EVC nonce + hash consumption

### What Solvers Cannot Do
- Steal entire user deposits (clearing prices bounded by limit prices)
- Alter signed operation parameters
- Cause undercollateralization (EVC health check)
- Access funds outside the settlement flow

### Known Risks
- **Frontend misconfiguration**: Wrong `receiver` address sends funds to inaccessible address
- **Interest accumulation**: Close position needs buyAmount buffer for accrued interest
- **Inbox conflicts**: Don't submit multiple close operations for same subaccount simultaneously
- **LTV differences**: Collateral swap to lower-LTV vault may require more collateral

## Documentation Index

- [`docs/01-overview.md`](docs/01-overview.md) - Architecture, wrapper pattern, authorization flows, dependency overview
- [`docs/02-open-position.md`](docs/02-open-position.md) - Open/grow leveraged positions, parameters, CoW order construction, error scenarios
- [`docs/03-close-position.md`](docs/03-close-position.md) - Close/reduce positions, Inbox pattern, EIP-1271 signing, interest handling
- [`docs/04-collateral-swap.md`](docs/04-collateral-swap.md) - Swap collateral between vaults, subaccount handling, LTV considerations
- [`docs/05-security-considerations.md`](docs/05-security-considerations.md) - Threat model, security properties, edge cases, audit checklist
