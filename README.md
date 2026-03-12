# Euler-CoW Protocol Integration Contracts

Smart contracts enabling leveraged position management (open/close/collateral swap) through CoW Protocol settlements combined with Ethereum Vault Connector (EVC) operations.

## Build

```shell
git submodule update --init --recursive
forge build
```

## Test

Tests require a mainnet fork RPC endpoint:

```shell
MAINNET_RPC_URL="<rpc-url>" FORK_RPC_URL="<rpc-url>" forge test
```

## Documentation

See `docs/` for detailed protocol documentation and `poc.md` for PoC testing guide.
