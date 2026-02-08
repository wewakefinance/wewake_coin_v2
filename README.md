# WeWake WAKE Token

Minimal ERC20 token with governance features used by the WeWake project.

This repository contains the `WeWakeCoin` contract (ERC20 + Permit + Votes) and
unit tests implemented with Foundry.

## Status

- Contract: `src/WeWakeCoin.sol` (ERC20, ERC20Permit, ERC20Votes, Ownable)
- Tests: `test/WeWakeCoin.t.sol` (unit tests for burn timelock, permissions, votes)
- CI: GitHub Actions (runs `forge test`)

## Highlights

- Timelocked burn workflow: owner calls `openBurn(amount)` to lock an amount
  for burning after a timelock. `finishBurn()` burns only the previously
  locked amount.
- Recent fix: the contract now stores an explicit `_burnAmount` so tokens sent
  to the contract after `openBurn` are not accidentally burned.

## Prerequisites

- Linux / macOS / Windows WSL
- Foundry (forge, cast, anvil). Install with:

```bash
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

## Quick start

Clone and run tests:

```bash
git clone https://github.com/wewakefinance/wewake_coin_v2
cd wewake_coin_v2
forge test
```

Run a single test or contract:

```bash
forge test --match-contract WeWakeCoinTest
forge test --match-test testFinishBurnDoesNotBurnExtraTokens
```

Start a local node with Anvil:

```bash
anvil
```

## Deploy (example)

Use `forge script` with `--broadcast` to publish a script in `script/`.

```bash
forge script script/WeWakeCoin.s.sol:WeWakeCoinScript \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

## Testing notes

- Unit tests exercise the timelock burn flow and votes/delegation. All tests
  should pass locally (`forge test`).
- A test `testFinishBurnDoesNotBurnExtraTokens` was added to ensure that only
  the explicitly locked amount is burned and that later transfers to the
  contract are preserved.

## Security & recommendations

- `finishBurn()` is currently public — decide whether to restrict it to
  `onlyOwner` or keep it callable by anyone (gas-paid finalization). Document
  the intended behavior in the contract NatSpec.
- Consider adding a `cancelBurn()` for owner-initiated rollback before
  timelock expiry, if desired by the protocol design.
- Use audits and automated tools (Slither, MythX) for production releases.

## Contributing

Please open issues or pull requests. Follow the existing code style and run
`forge test` before submitting changes.

## License

MIT
