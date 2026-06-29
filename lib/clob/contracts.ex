defmodule Polymarket.Clob.Contracts do
  @moduledoc """
  On-chain contract addresses for the Polymarket CTF Exchange, keyed by chain and
  by whether the market is a *negative-risk* market.

  Only the data needed to sign and post V2 orders is included: the V2 exchange,
  which is the EIP-712 "verifying contract". Polymarket runs on Polygon mainnet
  (chain id 137); Amoy (80002) is its testnet. A market's `neg_risk?` flag selects
  a different exchange deployment, so it is part of the key.

  Addresses (from the reference `rs-clob-client-v2`) are stored as raw 20-byte
  binaries, ready to feed into EIP-712 encoding.
  """

  @polygon 137
  @amoy 80_002

  @exchange_v2 %{
    {@polygon, false} => Base.decode16!("E111180000d2663C0091e4f400237545B87B996B", case: :mixed),
    {@polygon, true} => Base.decode16!("e2222d279d744050d28e00520010520000310F59", case: :mixed),
    {@amoy, false} => Base.decode16!("E111180000d2663C0091e4f400237545B87B996B", case: :mixed),
    {@amoy, true} => Base.decode16!("e2222d279d744050d28e00520010520000310F59", case: :mixed)
  }

  @doc "Polygon mainnet chain id (137)."
  @spec polygon() :: 137
  def polygon, do: @polygon

  @doc "Amoy testnet chain id (80002)."
  @spec amoy() :: 80_002
  def amoy, do: @amoy

  @doc """
  Returns the 20-byte V2 exchange ("verifying contract") address for `chain_id`
  and `neg_risk?`, or `:error` for an unsupported chain.
  """
  @spec exchange_v2(integer(), boolean()) :: {:ok, <<_::160>>} | :error
  def exchange_v2(chain_id, neg_risk?) when is_integer(chain_id) and is_boolean(neg_risk?) do
    Map.fetch(@exchange_v2, {chain_id, neg_risk?})
  end
end
