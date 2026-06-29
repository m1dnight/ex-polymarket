# Examples

Runnable scripts that exercise the live Polymarket CLOB API end to end. Run them
with `mix run`, supplying your wallet's private key via the `PK` environment
variable (kept out of your shell history — e.g. `PK=$(cat ~/.pmkey)`).

These scripts make **real** network calls. Obtaining API credentials and posting
an order needs no funds and is safe to run; an unfunded wallet simply has its
orders rejected.

## `derive_api_key.exs`

Obtains CLOB API credentials (L1 ClobAuth auth) for a wallet. A successful result
means the server accepted your EIP-712 signature.

```sh
PK=0x<key> mix run examples/derive_api_key.exs
```

## `post_order.exs`

Runs the whole pipeline: derive credentials → build and EIP-712-sign an order →
L2 HMAC → `POST /order` → parse the response.

```sh
PK=0x<owner key> FUNDER=0x<deposit wallet> TOKEN_ID=<active market token> \
  mix run examples/post_order.exs
```

Polymarket does not accept a bare EOA as an order's `maker` — orders are made from
your **deposit wallet** (the "funder"). The default `WALLET_TYPE=poly1271` flow sets
`maker == signer == FUNDER` and signs it (ERC-1271) with your owner EOA (`PK`).
Your `FUNDER` is the deposit address shown on [polymarket.com](https://polymarket.com);
`PK` is the wallet that owns it. (`Polymarket.Clob.DepositWallet` can *compute* the
deterministic proxy/safe address, but the authoritative funder is whatever your
account uses.)

Both scripts accept `CHAIN_ID` (137 Polygon, default; 80002 Amoy) and `CLOB_URL`
(e.g. the staging host). See each script's header for the full set of options.
