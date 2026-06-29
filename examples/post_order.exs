# Sign and post an order to the Polymarket CLOB — the full pipeline: L1 auth ->
# API credentials -> EIP-712 order signing -> L2 HMAC -> POST /order.
#
# Polymarket trades from a deposit wallet (the "funder"), not a bare EOA. The
# default flow is poly1271: maker == signer == your funder address, signed
# (ERC-1271) by your owner EOA (PK). With an unfunded wallet the order is rejected
# with a %ClobError{} (e.g. insufficient balance), which still exercises the whole
# stack.
#
# Usage:
#   WALLET_PK=0x<owner key> FUNDER=0x<deposit wallet> TOKEN_ID=<active market token> \
#     mix run examples/post_order.exs
#
# Optional env:
#   WALLET_TYPE   "poly1271" (default, deposit-wallet flow) | "eoa" (bare EOA, no
#                 funder) | "proxy" | "gnosis_safe". poly1271/proxy/gnosis_safe
#                 require a funder. proxy/gnosis_safe sign with the owner EOA but set
#                 maker = funder, signer = EOA.
#   FUNDER        Your deposit-wallet ("maker") address, as shown on polymarket.com.
#                 Falls back to POLYMARKET_ADDRESS if FUNDER is unset.
#   CHAIN_ID      137 (default, Polygon) or 80002 (Amoy)
#   NEG_RISK      "true" if the market is negative-risk (default "false")
#   SIDE          "BUY" (default) or "SELL"
#   MAKER_AMOUNT  base units you provide, 6 decimals (default 1000000 = 1 USDC)
#   TAKER_AMOUNT  base units you receive, 6 decimals (default 2000000 = 2 shares)
#   CLOB_URL      override the base URL (e.g. the staging host)

alias Polymarket.Clob
alias Polymarket.Clob.OrderSigner
alias Polymarket.Crypto
alias Polymarket.Schemas.Order
alias Polymarket.Schemas.SendOrder

pk_hex = "WALLET_PK" |> System.fetch_env!() |> String.replace_prefix("0x", "")

pk =
  case Base.decode16(pk_hex, case: :mixed) do
    {:ok, <<_::256>> = bytes} ->
      bytes

    _other ->
      IO.puts("PK must be a 32-byte private key as 64 hex chars (optionally 0x-prefixed).")
      System.halt(1)
  end

token_id = "TOKEN_ID" |> System.fetch_env!() |> String.to_integer()
chain_id = "CHAIN_ID" |> System.get_env("137") |> String.to_integer()
neg_risk = System.get_env("NEG_RISK", "false") == "true"
side = if System.get_env("SIDE", "BUY") == "SELL", do: :sell, else: :buy
maker_amount = "MAKER_AMOUNT" |> System.get_env("1000000") |> String.to_integer()
taker_amount = "TAKER_AMOUNT" |> System.get_env("2000000") |> String.to_integer()
wallet_type = System.get_env("WALLET_TYPE", "poly1271")

if url = System.get_env("CLOB_URL"), do: Application.put_env(:ex_polymarket, :clob_url, url)

address = Crypto.address_from_private_key(pk)

funder = fn ->
  case System.get_env("FUNDER") || System.get_env("POLYMARKET_ADDRESS") do
    nil ->
      IO.puts("Set FUNDER to your deposit-wallet address (shown on polymarket.com).")
      System.halt(1)

    hex ->
      hex |> String.replace_prefix("0x", "") |> Base.decode16!(case: :mixed)
  end
end

# maker is the wallet whose funds back the order; signer is the key that signs.
{maker, signer, signature_type} =
  case wallet_type do
    "poly1271" -> {funder.(), funder.(), :poly1271}
    "proxy" -> {funder.(), address, :proxy}
    "gnosis_safe" -> {funder.(), address, :gnosis_safe}
    _eoa -> {address, address, :eoa}
  end

IO.puts("Signer (EOA):  0x#{Base.encode16(address, case: :lower)}")
IO.puts("Maker:         0x#{Base.encode16(maker, case: :lower)} (#{signature_type})")
IO.puts("Chain:         #{chain_id}  neg_risk: #{neg_risk}")
IO.puts("Order:         #{side} token #{token_id}, maker=#{maker_amount} taker=#{taker_amount}\n")

# 1. API credentials (L1) — derived from the owner EOA.
credentials =
  case Clob.create_or_derive_api_key(pk, chain_id) do
    {:ok, creds} ->
      IO.puts("Got credentials: #{inspect(creds)}\n")
      creds

    {:error, reason} ->
      IO.puts("Could not obtain credentials (#{inspect(reason)}). Stopping.")
      System.halt(1)
  end

# 2. Build and sign the order.
order = %Order{
  salt: :rand.uniform(1_000_000_000_000),
  maker: maker,
  signer: signer,
  token_id: token_id,
  maker_amount: maker_amount,
  taker_amount: taker_amount,
  side: side,
  signature_type: signature_type,
  timestamp: System.os_time(:millisecond)
}

{:ok, signature} = OrderSigner.sign(order, pk, chain_id, neg_risk)
send_order = %SendOrder{order: order, signature: signature, owner: credentials.api_key}

# 3. Post it.
case Clob.post_order(send_order, credentials) do
  {:ok, response} ->
    IO.puts("Order accepted: #{inspect(response)}")

  {:error, error} ->
    IO.puts("Order rejected: #{inspect(error)}")
end
