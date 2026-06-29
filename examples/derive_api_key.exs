# Obtain Polymarket CLOB API credentials from a private key (L1 ClobAuth auth).
#
# These credentials (api_key / secret / passphrase) authorise every authenticated
# request via the L2 HMAC headers — see examples/post_order.exs. Deriving them
# needs no funds and places no orders, so it is a safe way to check L1 end to end:
# a successful result means the server accepted your EIP-712 ClobAuth signature.
#
# Usage:
#   WALLET_PK=0x<your private key> mix run examples/derive_api_key.exs
#
# Optional env:
#   CHAIN_ID   137 Polygon / production (default), 80002 Amoy
#   NONCE      API-key slot (default 0)
#   CLOB_URL   override the base URL, e.g. https://clob-staging.polymarket.com

alias Polymarket.Clob
alias Polymarket.Crypto

pk_hex = "WALLET_PK" |> System.fetch_env!() |> String.replace_prefix("0x", "")

pk =
  case Base.decode16(pk_hex, case: :mixed) do
    {:ok, <<_::256>> = bytes} ->
      bytes

    _other ->
      IO.puts("PK must be a 32-byte private key as 64 hex chars (optionally 0x-prefixed).")
      System.halt(1)
  end

chain_id = "CHAIN_ID" |> System.get_env("137") |> String.to_integer()
nonce = "NONCE" |> System.get_env("0") |> String.to_integer()

if url = System.get_env("CLOB_URL"), do: Application.put_env(:ex_polymarket, :clob_url, url)

IO.puts("Wallet:   0x#{Base.encode16(Crypto.address_from_private_key(pk), case: :lower)}")
IO.puts("Chain ID: #{chain_id}\n")

case Clob.create_or_derive_api_key(pk, chain_id, nonce: nonce) do
  {:ok, credentials} ->
    IO.puts("Got credentials (secret/passphrase redacted): #{inspect(Map.from_struct(credentials), limit: :infinity)}")

  {:error, reason} ->
    IO.puts("Could not obtain credentials: #{inspect(reason)}")
    System.halt(1)
end
