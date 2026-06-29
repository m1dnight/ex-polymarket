defmodule Polymarket.Schemas.Order do
  @moduledoc """
  A Polymarket CLOB **V2** order — the value that gets EIP-712 signed and posted
  to `POST /order`.

  Unlike the response schemas in this namespace (which are parsed from JSON), an
  order is an *outbound*, caller-constructed value. Its fields mirror the on-chain
  CTF Exchange V2 order struct.

  The eleven *signed* fields — `salt`, `maker`, `signer`, `token_id`,
  `maker_amount`, `taker_amount`, `side`, `signature_type`, `timestamp`,
  `metadata`, `builder` — are hashed and signed by `Polymarket.Clob.OrderSigner`.
  `expiration` is **not** part of the V2 signed struct (it travels on the outer
  JSON payload), and is carried here only for that later use.

  Representation:

    * amounts (`maker_amount`, `taker_amount`), `salt`, `token_id`, `timestamp`
      and `expiration` are non-negative integers in base units — USDC has 6
      decimals, so 1 USDC is `1_000_000`;
    * `maker` and `signer` are raw 20-byte address binaries;
    * `metadata` and `builder` are raw 32-byte binaries (default all-zero);
    * `side` and `signature_type` are atoms, mapped to their on-chain integer
      values by `side_value/1` and `signature_type_value/1`.
  """

  use TypedStruct

  @typedoc "Order direction: `:buy` (0) or `:sell` (1)."
  @type side :: :buy | :sell

  @typedoc "How the order is authorised on-chain."
  @type signature_type :: :eoa | :proxy | :gnosis_safe | :poly1271

  typedstruct do
    field(:salt, non_neg_integer(), enforce: true)
    field(:maker, <<_::160>>, enforce: true)
    field(:signer, <<_::160>>, enforce: true)
    field(:token_id, non_neg_integer(), enforce: true)
    field(:maker_amount, non_neg_integer(), enforce: true)
    field(:taker_amount, non_neg_integer(), enforce: true)
    field(:side, side(), enforce: true)
    field(:timestamp, non_neg_integer(), enforce: true)
    field(:signature_type, signature_type(), default: :eoa)
    field(:expiration, non_neg_integer(), default: 0)
    field(:metadata, <<_::256>>, default: <<0::256>>)
    field(:builder, <<_::256>>, default: <<0::256>>)
  end

  @doc "The on-chain `uint8` value for a `t:side/0`."
  @spec side_value(side()) :: 0..1
  def side_value(:buy), do: 0
  def side_value(:sell), do: 1

  @doc "The on-chain `uint8` value for a `t:signature_type/0`."
  @spec signature_type_value(signature_type()) :: 0..3
  def signature_type_value(:eoa), do: 0
  def signature_type_value(:proxy), do: 1
  def signature_type_value(:gnosis_safe), do: 2
  def signature_type_value(:poly1271), do: 3
end
