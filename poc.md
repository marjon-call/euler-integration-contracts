# PoC Guide - Euler-CoW Protocol Integration

## PoC Template

Use `test/PoC.t.sol` as the base for all proof-of-concept exploits. It includes:
- Minimal interfaces for all in-scope contracts (IERC20, IEVault, IEVC, ICowSettlement, ICowAuthentication, ICowWrapper, IPreApprovedHashes, IInboxFactory)
- All mainnet contract addresses (CoW Settlement, EVC, Euler Vaults, tokens)
- Mainnet fork setup via `MAINNET_RPC_URL`

## Running PoC Tests

```bash
MAINNET_RPC_URL="$MAINNET_RPC_URL" forge test --match-contract PoCTest -vvv
```

## Protocol Overview

Euler-CoW integration contracts enable leveraged position management (open/close/collateral swap) through CoW Protocol settlements combined with EVC batch operations. All operations are atomic within an EVC batch.

### Contract Hierarchy

```
CowWrapper (base: solver auth, wrapper chaining)
  └── CowEvcBaseWrapper (EVC batch coordination, EIP-712 auth, pre-approved hashes)
        ├── CowEvcOpenPositionWrapper   (open/grow leveraged positions)
        ├── CowEvcClosePositionWrapper  (close/reduce positions, uses Inbox)
        └── CowEvcCollateralSwapWrapper (swap collateral between vaults)
```

Supporting contracts:
- **Inbox** - Per-(owner, subaccount) contract for ClosePosition; receives swap output, implements EIP-1271, repays debt
- **InboxFactory** - CREATE2 deployment of Inbox contracts
- **PreApprovedHashes** - On-chain hash pre-approval (alternative to EVC permit signatures)
- **CowWrapperHelpers** - Off-chain wrapper data validation and encoding

### Key Flows

1. **Open Position**: deposit collateral -> borrow -> CoW swap borrowed assets to more collateral
2. **Close Position**: transfer collateral to Inbox -> CoW swap to debt asset -> Inbox repays debt -> excess returned
3. **Collateral Swap**: enable new collateral vault -> transfer old collateral -> CoW swap old vault tokens to new vault tokens

### Authorization

Two auth flows:
- **EVC Permit**: Off-chain EIP-712 signature over `encodePermitData(params)` + CoW order signature
- **Pre-Approved Hash**: On-chain `setPreApprovedHash(hash, true)` + EVC operator + CoW pre-signature

### Security Assumptions

- Solvers are semi-trusted (subject to slashing, cannot set clearing prices below user limits)
- EVC enforces account health at batch end (undercollateralized positions revert)
- User authorization (permit or pre-approved hash) required for all operations
- Reentrancy protection via transient storage hash check on `evcInternalSettle` callback
- Vulnerabilities in external contracts (EVC, CoW Settlement, Euler Vaults) are out of scope

## Key Addresses (Ethereum Mainnet)

| Contract | Address |
|----------|---------|
| CoW Settlement | `0x9008D19f58AAbD9eD0D60971565AA8510560ab41` |
| CoW Vault Relayer | `0xC92E8bdf79f0507f65a392b0ab4667716BFE0110` |
| CoW Authenticator (proxy) | `0x2c4c28DDBdAc9C5E7055b4C863b72eA0149D8aFE` |
| EVC | `0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383` |
| eUSDS Vault | `0x07F9A54Dc5135B9878d6745E267625BF0E206840` |
| eWETH Vault | `0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2` |
| eWBTC Vault | `0x998D761eC1BAdaCeb064624cc3A1d37A46C88bA4` |
| USDS (proxy) | `0xdC035D45d973E3EC169d2276DDab16f1e407384F` |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` |
| WBTC | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` |
| Allow List Manager | `0xA03be496e67Ec29bC62F01a428683D7F9c204930` |

## Detailed Documentation

See `docs/` for full documentation:
- `docs/01-overview.md` - Architecture, wrapper pattern, authorization flows
- `docs/02-open-position.md` - Open position parameters, CoW order construction
- `docs/03-close-position.md` - Close position, Inbox pattern, EIP-1271 signing
- `docs/04-collateral-swap.md` - Collateral swap, subaccount handling
- `docs/05-security-considerations.md` - Threat model, security properties, audit checklist
